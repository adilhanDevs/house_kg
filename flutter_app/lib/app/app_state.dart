// Состояние приложения: избранное, фильтр, кошелёк, черновик объявления и
// режим клиент/исполнитель. Живёт над навигатором, поэтому переживает переходы
// между экранами.
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import '../data/ad_media.dart';
import '../data/listings.dart';

/// Операция по кошельку — строка «Истории пополнения и трат».
@immutable
class WalletEntry {
  const WalletEntry({
    required this.day,
    required this.label,
    required this.bricks,
    required this.kind,
  });

  final String day;
  final String label;
  final int bricks;
  final WalletEntryKind kind;

  bool get income => bricks > 0;
}

enum WalletEntryKind { topup, spend, bonus }

/// Вкладки «Истории пополнения и трат» — `HISTORY_TABS` прототипа.
enum WalletTab {
  all('Все операции'),
  topup('Пополнение'),
  spend('Списание'),
  bonus('Бонусы');

  const WalletTab(this.label);
  final String label;
}

/// Строка «Истории просмотров»: какой объект открывали и когда.
@immutable
class ViewEntry {
  const ViewEntry(this.id, this.at);

  final String id;
  final DateTime at;

  Listing get listing => listingById(id);
}

class AppState extends ChangeNotifier {
  AppState({MediaSource media = const DeviceMedia()}) : _media = media {
    _initAuth();
  }

  /// Откуда берутся файлы для объявления — галерея и камера устройства.
  final MediaSource _media;

  // ---------------------------------------------------------------- авторизация и API
  String? _accessToken;
  String? _refreshToken;
  
  String? userName;
  String? userPhone;
  int walletBalance = 0;
  bool isPro = false;
  
  final ListingApiClient apiClient = ListingApiClient(baseUrl: 'https://adilhan1234.pythonanywhere.com');

  bool get isAuthenticated => _accessToken != null;

  Future<void> _initAuth() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    if (_accessToken != null) {
      apiClient.setToken(_accessToken);
      await fetchProfile();
    }
    await fetchFilterOptions('Бишкек');
    notifyListeners();
  }

  Future<void> fetchFilterOptions(String city) async {
    try {
      filterOptions = await apiClient.getFilterOptions(city: city);
      notifyListeners();
    } catch (e) {
      print('Failed to fetch filter options: $e');
    }
  }

  Future<void> fetchProfile() async {
    try {
      final profile = await apiClient.getMe();
      userName = profile['name'] as String?;
      userPhone = profile['phone'] as String?;
      if (profile['wallet_balance'] is Map) {
        walletBalance = profile['wallet_balance']['balance'] as int? ?? 0;
      } else {
        walletBalance = profile['wallet_balance'] as int? ?? 0;
      }
      isPro = profile['is_pro'] as bool? ?? false;
      final hasSellerProfile = profile['has_seller_profile'] as bool? ?? false;
      final sellerKind = profile['seller_kind'] as String?;
      if (isPro || hasSellerProfile || (sellerKind != null && sellerKind.isNotEmpty)) {
        _pro = true;
      }
      notifyListeners();
    } catch (e) {
      print('Failed to fetch profile: $e');
    }
  }

  Future<void> fetchWalletBalance() async {
    try {
      final response = await apiClient.getWalletBalance();
      walletBalance = response['balance'] as int? ?? 0;
      notifyListeners();
    } catch (e) {
      print('Failed to fetch wallet balance: $e');
    }
  }

  Future<void> logout() async {
    if (_refreshToken != null) {
      try {
        await apiClient.logout(_refreshToken!);
      } catch (e) {
        print('Logout request failed: $e');
      }
    }
    _accessToken = null;
    _refreshToken = null;
    userName = null;
    userPhone = null;
    walletBalance = 0;
    isPro = false;
    
    _favourites.clear();
    _viewed.clear();
    _query = '';
    _pro = false;

    apiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    notifyListeners();
  }

  Future<void> sendOtp(String phone) async {
    await apiClient.requestOtp(phone);
  }

  Future<void> verifyAndLogin(String phone, String code, {String? name}) async {
    final response = await apiClient.verifyOtp(phone, code, name: name);
    await _saveTokens(response);
  }

  Future<void> loginWithPassword(String phone, String password) async {
    final response = await apiClient.loginWithPassword(phone, password);
    await _saveTokens(response);
  }

  Future<void> registerPro(String phone, String name, String password, String iin) async {
    final response = await apiClient.registerPro(phone, name, password, iin);
    // If the server returns tokens immediately:
    if (response.containsKey('access')) {
      await _saveTokens(response);
    }
  }

  Future<void> _saveTokens(Map<String, dynamic> response) async {
    if (response.containsKey('access')) {
      _accessToken = response['access'];
      apiClient.setToken(_accessToken);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
    }
    if (response.containsKey('refresh')) {
      _refreshToken = response['refresh'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', _refreshToken!);
    }
    if (response.containsKey('user') && response['user'] is Map) {
      final user = response['user'] as Map<String, dynamic>;
      userName = user['name'] as String?;
      userPhone = user['phone'] as String?;
      isPro = user['is_pro'] as bool? ?? false;
      final hasSeller = user['has_seller_profile'] as bool? ?? false;
      final sellerKind = user['seller_kind'] as String?;
      if (isPro || hasSeller || (sellerKind != null && sellerKind.isNotEmpty)) {
        _pro = true;
      }
    }
    await fetchProfile();
    notifyListeners();
  }

  // ---------------------------------------------------------------- избранное
  final Set<String> _favourites = {};

  Set<String> get favourites => Set.unmodifiable(_favourites);
  bool isFavourite(String id) => _favourites.contains(id);

  void syncFavourites(List<Listing> listings) {
    bool changed = false;
    for (final listing in listings) {
      if (listing.isFavourite && !_favourites.contains(listing.id)) {
        _favourites.add(listing.id);
        changed = true;
      } else if (!listing.isFavourite && _favourites.contains(listing.id)) {
        _favourites.remove(listing.id);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  Future<void> toggleFavourite(String id) async {
    final wasFavourited = _favourites.contains(id);
    
    // Optimistic UI update
    if (wasFavourited) {
      _favourites.remove(id);
    } else {
      _favourites.add(id);
    }
    notifyListeners();

    try {
      final response = await apiClient.toggleFavourite(id);
      final isFavourited = response['is_favourited'] == true;
      
      // Re-sync with actual response just in case
      bool changed = false;
      if (isFavourited && !_favourites.contains(id)) {
        _favourites.add(id);
        changed = true;
      } else if (!isFavourited && _favourites.contains(id)) {
        _favourites.remove(id);
        changed = true;
      }
      if (changed) notifyListeners();
    } catch (e) {
      // Revert on error
      if (wasFavourited) {
        _favourites.add(id);
      } else {
        _favourites.remove(id);
      }
      notifyListeners();
      print('Failed to toggle favourite: $e');
    }
  }

  // ------------------------------------------------------------------ фильтр
  Map<String, dynamic> filterOptions = {};
  String _query = '';
  final Set<PropertyKind> _kinds = {};
  final Set<int> _rooms = {};
  int? _customRooms;
  final Set<AreaRange> _areas = {};
  AreaRange? _customArea;
  final Set<SellerKind> _sellers = {};
  bool _secondaryOnly = false;
  bool _series103 = false;
  final Set<String> _series = {};
  int? _priceFrom;
  int? _priceTo;

  String get query => _query;
  Set<PropertyKind> get kinds => Set.unmodifiable(_kinds);
  Set<int> get rooms => Set.unmodifiable(_rooms);
  int? get customRooms => _customRooms;
  Set<AreaRange> get areas => Set.unmodifiable(_areas);
  AreaRange? get customArea => _customArea;
  Set<SellerKind> get sellers => Set.unmodifiable(_sellers);
  bool get secondaryOnly => _secondaryOnly;
  Set<String> get series => Set.unmodifiable(_series);
  int? get priceFrom => _priceFrom;
  int? get priceTo => _priceTo;
  bool get ownerOnly => _sellers.contains(SellerKind.owner);

  /// Все выбранные диапазоны квадратуры — чипы плюс введённый вручную.
  List<AreaRange> get areaFilter =>
      [..._areas, if (_customArea != null) _customArea!];

  bool get hasFilter =>
      _kinds.isNotEmpty ||
      _rooms.isNotEmpty ||
      areaFilter.isNotEmpty ||
      _sellers.isNotEmpty ||
      _secondaryOnly ||
      _series.isNotEmpty ||
      _priceFrom != null ||
      _priceTo != null;

  /// Сколько условий выбрано — показывается точкой на иконке фильтра.
  int get filterCount =>
      _kinds.length +
      _rooms.length +
      areaFilter.length +
      _sellers.length +
      (_secondaryOnly ? 1 : 0) +
      _series.length +
      (_priceFrom != null || _priceTo != null ? 1 : 0);

  void toggleSeries(String slug) {
    _series.contains(slug) ? _series.remove(slug) : _series.add(slug);
    notifyListeners();
  }

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  Map<String, dynamic> get filterParams {
    final params = <String, dynamic>{};
    if (_query.isNotEmpty) params['search'] = _query;
    if (_kinds.isNotEmpty) params['kind'] = _kinds.map((k) => k.name).join(',');
    if (_rooms.isNotEmpty) params['rooms'] = _rooms.join(',');
    if (areaFilter.isNotEmpty) params['area_ranges'] = areaFilter.map((a) => a.label).join(',');
    if (_sellers.isNotEmpty) params['seller_kind'] = _sellers.map((s) => s.name).join(',');
    if (_secondaryOnly) params['is_secondary'] = 'true';
    if (_series.isNotEmpty) params['series'] = _series.join(',');
    if (_priceFrom != null) params['price_min'] = _priceFrom.toString();
    if (_priceTo != null) params['price_max'] = _priceTo.toString();
    return params;
  }

  void toggleKind(PropertyKind kind) {
    _kinds.contains(kind) ? _kinds.remove(kind) : _kinds.add(kind);
    notifyListeners();
  }

  void toggleRooms(int count) {
    _rooms.contains(count) ? _rooms.remove(count) : _rooms.add(count);
    notifyListeners();
  }

  void setCustomRooms(int? count) {
    if (_customRooms == count) return;
    if (_customRooms != null) {
      _rooms.remove(_customRooms);
    }
    _customRooms = count;
    if (count != null && count > 0) {
      _rooms.add(count);
    }
    notifyListeners();
  }

  void toggleArea(AreaRange range) {
    _areas.contains(range) ? _areas.remove(range) : _areas.add(range);
    notifyListeners();
  }

  void setCustomArea(AreaRange? range) {
    if (_customArea == range) return;
    _customArea = range;
    notifyListeners();
  }

  void toggleSeller(SellerKind seller) {
    _sellers.contains(seller) ? _sellers.remove(seller) : _sellers.add(seller);
    notifyListeners();
  }

  void setSecondaryOnly(bool value) {
    _secondaryOnly = value;
    notifyListeners();
  }


  void setPrice({int? from, int? to}) {
    _priceFrom = from;
    _priceTo = to;
    notifyListeners();
  }

  void setOwnerOnly(bool value) {
    value ? _sellers.add(SellerKind.owner) : _sellers.remove(SellerKind.owner);
    notifyListeners();
  }

  void resetFilter() {
    _kinds.clear();
    _rooms.clear();
    _customRooms = null;
    _areas.clear();
    _sellers.clear();
    _customArea = null;
    _secondaryOnly = false;
    _series103 = false;
    _priceFrom = null;
    _priceTo = null;
    notifyListeners();
  }

  /// Каталог с учётом поиска и фильтра.
  List<Listing> get results {
    final q = _query.trim().toLowerCase();
    return kListings.where((l) {
      if (q.isNotEmpty &&
          !l.district.toLowerCase().contains(q) &&
          !l.kind.label.toLowerCase().contains(q)) {
        return false;
      }
      if (_kinds.isNotEmpty && !_kinds.contains(l.kind)) return false;
      if (_rooms.isNotEmpty && !_rooms.contains(l.rooms)) return false;
      final areas = areaFilter;
      if (areas.isNotEmpty && !areas.any((r) => r.has(l.area))) return false;
      if (_secondaryOnly && !l.secondary) return false;
      if (_series103 && l.series != '103') return false;
      if (_sellers.isNotEmpty && !_sellers.contains(l.seller)) return false;
      if (_priceFrom != null && l.priceUsd < _priceFrom!) return false;
      if (_priceTo != null && l.priceUsd > _priceTo!) return false;
      return true;
    }).toList();
  }

  // ---------------------------------------------------------------- кошелёк
  int _bricks = 16700;
  final List<WalletEntry> _wallet = [
    // строки из макета «Истории пополнения и трат»
    const WalletEntry(day: '21 августа', label: '+12 000 сом (12 000 кирпичей)', bricks: 12000, kind: WalletEntryKind.topup),
    const WalletEntry(day: '21 августа', label: '+1 200 кирпичей (бонус за пополнение)', bricks: 1200, kind: WalletEntryKind.bonus),
    const WalletEntry(day: '21 августа', label: '+300 кирпичей (бонус за квест)', bricks: 300, kind: WalletEntryKind.bonus),
    const WalletEntry(day: '21 августа', label: '-500 кирпичей', bricks: -500, kind: WalletEntryKind.spend),
    const WalletEntry(day: '20 августа', label: '+12 000 сом (12 000 кирпичей)', bricks: 12000, kind: WalletEntryKind.topup),
    const WalletEntry(day: '20 августа', label: '-500 кирпичей', bricks: -500, kind: WalletEntryKind.spend),
  ];

  int get bricks => _bricks;
  String get bricksLabel {
    final s = _bricks.toString();
    return s.length > 3 ? '${s.substring(0, s.length - 3)}.${s.substring(s.length - 3)}' : s;
  }

  List<WalletEntry> get wallet => List.unmodifiable(_wallet);

  List<WalletEntry> walletFor(WalletTab tab) => switch (tab) {
        WalletTab.all => wallet,
        WalletTab.topup => _wallet.where((e) => e.kind == WalletEntryKind.topup).toList(),
        WalletTab.spend => _wallet.where((e) => e.kind == WalletEntryKind.spend).toList(),
        WalletTab.bonus => _wallet.where((e) => e.kind == WalletEntryKind.bonus).toList(),
      };

  /// Пополнение: сумма в сомах даёт столько же кирпичей плюс 10% бонуса —
  /// как на экране «+12 000 сом → +1200 кирпичей».
  int topupAmount = 12000;
  int get topupBonus => (topupAmount * 0.1).round();

  void setTopupAmount(int value) {
    topupAmount = value;
    notifyListeners();
  }

  void commitTopup() {
    _bricks += topupAmount + topupBonus;
    _wallet.insertAll(0, [
      WalletEntry(
        day: 'Сегодня',
        label: '+${thousands(topupAmount)} сом (${thousands(topupAmount)} кирпичей)',
        bricks: topupAmount,
        kind: WalletEntryKind.topup,
      ),
      WalletEntry(
        day: 'Сегодня',
        label: '+${thousands(topupBonus)} кирпичей (бонус за пополнение)',
        bricks: topupBonus,
        kind: WalletEntryKind.bonus,
      ),
    ]);
    notifyListeners();
  }

  // --------------------------------------------------------- режим и профиль
  bool _pro = false;
  bool get pro => _pro;
  set pro(bool value) {
    if (_pro == value) return;
    _pro = value;
    notifyListeners();
  }


  // ------------------------------------------------------ история просмотров
  //
  // Пока объектов нет на сервере, историю ведёт само приложение: страница
  // объекта отмечается открытой, а чтобы экран не встречал пустотой на первом
  // запуске, несколько записей заведено заранее — по одной в день.
  final List<ViewEntry> _viewed = [
    for (var i = 0; i < kListings.length; i++)
      ViewEntry(
        kListings[i].id,
        DateTime.now().subtract(Duration(hours: 3 * i * i + 2)),
      ),
  ];

  List<ViewEntry> get viewed => List.unmodifiable(_viewed);

  /// Объект открыли — он поднимается наверх истории с текущим временем.
  void noteViewed(String id) {
    _viewed.removeWhere((e) => e.id == id);
    _viewed.insert(0, ViewEntry(id, DateTime.now()));
    notifyListeners();
  }

  void forgetViewed(Set<String> ids) {
    if (ids.isEmpty) return;
    _viewed.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
  }

  /// Выход из аккаунта: всё, что относится к сеансу, забывается — избранное,
  /// поиск с фильтром и режим исполнителя. Кошелёк и черновик привязаны к
  /// аккаунту, а не к устройству, поэтому их тоже сбрасывать нечестно: их
  /// подтянет следующий вход.
  void logOut() async {
    _favourites.clear();
    _viewed.clear();
    _query = '';
    _pro = false;
    _accessToken = null;
    _refreshToken = null;
    apiClient.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    resetFilter();
  }

  // ------------------------------------------------- черновик объявления
  final Set<PropertyKind> draftKinds = {PropertyKind.newBuilding};
  int draftRooms = 1;
  int draftFloor = 1;
  int draftFloors = 1;
  String draftArea = '';
  String draftDistrict = 'Район Бишкека';
  String draftBuilder = '';
  String draftPrice = '';
  bool draftUsd = true;
  bool draftOwner = true;
  bool draftAllowDownload = true;
  bool draftUseAdInfo = true;
  String? draftSlug;

  /// Сколько файлов принимает объявление — столько же обещает и подпись под
  /// кнопкой «Добавить».
  static const int draftMediaLimit = 20;

  /// Приложенные снимки и ролики. Первыми лежат кадры из макета: с ними экран
  /// сразу выглядит так, как нарисовано.
  final List<AdMedia> draftGallery = [
    const AdMedia.demo('assets/figma/2e62acec850fa8b9.jpg'),
    const AdMedia.demo('assets/figma/b76192aa900c610a.jpg'),
    const AdMedia.demo('assets/figma/92b0d143df96c511.jpg'),
    const AdMedia.demo('assets/figma/e267d094d7f9a8fc.jpg'),
    const AdMedia.demo('assets/figma/ccc665cff0c465a4.jpg'),
    const AdMedia.demo('assets/figma/231c034e3954a705.jpg'),
  ];

  final List<AdMedia> draftVideoList = [
    const AdMedia.demo('assets/figma/231c034e3954a705.jpg', video: true),
  ];

  int get draftPhotos => draftGallery.length;
  int get draftVideos => draftVideoList.length;

  /// Сколько ещё влезет — по нему кнопка «Добавить» гаснет.
  int get freePhotoSlots => draftMediaLimit - draftGallery.length;
  int get freeVideoSlots => draftMediaLimit - draftVideoList.length;

  /// Выбрать снимки. Возвращает, сколько добавилось: сверх предела файлы не
  /// берём, и экран говорит об этом вслух.
  Future<int> addPhotos({required bool camera}) async {
    final picked = await _media.photos(camera: camera);
    return _append(draftGallery, picked);
  }

  /// Выбрать ролик.
  Future<int> addVideo({required bool camera}) async {
    final picked = await _media.video(camera: camera);
    return _append(draftVideoList, [if (picked != null) picked]);
  }

  int _append(List<AdMedia> into, List<AdMedia> picked) {
    final room = draftMediaLimit - into.length;
    final taken = picked.take(math.max(0, room)).toList();
    if (taken.isEmpty) return 0;
    into.addAll(taken);
    notifyListeners();
    return taken.length;
  }

  void removeMedia(List<AdMedia> from, AdMedia media) {
    from.remove(media);
    notifyListeners();
  }

  /// Продвижение: сколько дней и чем платим.
  int promoDays = 1;
  bool promoFromBalance = false;
  int get promoCost => promoDays * 780;

  void setDraft(void Function() change) {
    change();
    notifyListeners();
  }
}

/// Доступ к состоянию из дерева.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден выше по дереву');
    return scope!.notifier!;
  }

  /// Без подписки на изменения — для обработчиков нажатий.
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope не найден выше по дереву');
    return scope!.notifier!;
  }
}

// Состояние приложения: избранное, фильтр, кошелёк, черновик объявления и
// режим клиент/исполнитель. Живёт над навигатором, поэтому переживает переходы
// между экранами.
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/api_client.dart';
import '../data/api_config.dart';
import '../data/api_exceptions.dart';
import '../data/ad_media.dart';
import '../data/topup.dart';
import '../data/video_poster.dart';
import '../data/kind_fields.dart';
import '../data/listing_payload.dart';
import '../data/listings.dart';
import '../data/tariff.dart';

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
  const ViewEntry(this.id, this.at, {this.listingData});

  final String id;
  final DateTime at;
  final Listing? listingData;

  Listing get listing => listingData ?? listingById(id);
}

class AppState extends ChangeNotifier {
  AppState({
    MediaSource media = const DeviceMedia(),
    ListingApiClient? apiClient,
    VideoPosterCapture? posterCapture,
  })  : _media = media,
        _posterCapture = posterCapture ?? captureVideoPoster,
        apiClient = apiClient ??
            ListingApiClient(baseUrl: kApiBaseUrl) {
    this.apiClient.setTokenRefreshCallback(_handleTokenRefresh);
    authInitialized = _initAuth();
  }

  Future<void>? authInitialized;

  /// Чем снимается кадр-обложка ролика. Подменяется в тестах.
  final VideoPosterCapture _posterCapture;

  /// Откуда берутся файлы для объявления — галерея и камера устройства.
  final MediaSource _media;

  // ---------------------------------------------------------------- авторизация и API
  String? _accessToken;
  String? _refreshToken;
  
  String? userName;
  String? userPhone;
  String? userAvatarUrl;
  /// `owner` | `realtor` | `agency` — из профиля (`seller_kind`).
  String? sellerKind;
  int walletBalance = 0;
  bool isPro = false;
  bool isInitializing = true;
  
  final ListingApiClient apiClient;

  bool get isAuthenticated => _accessToken != null;

  Future<String?> _handleTokenRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = _refreshToken ?? prefs.getString('refresh_token');
    if (refresh != null && refresh.isNotEmpty) {
      try {
        final data = await apiClient.refreshToken(refresh);
        final newAccess = data['access'] as String?;
        final newRefresh = data['refresh'] as String?;
        if (newAccess != null && newAccess.isNotEmpty) {
          _accessToken = newAccess;
          await prefs.setString('access_token', newAccess);
          if (newRefresh != null && newRefresh.isNotEmpty) {
            _refreshToken = newRefresh;
            await prefs.setString('refresh_token', newRefresh);
          }
          apiClient.setToken(newAccess);
          return newAccess;
        }
      } catch (e) {
        debugPrint('Token refresh with refresh_token failed: $e');
      }
    }

    final phoneToUse = (userPhone != null && userPhone!.isNotEmpty)
        ? userPhone!
        : (prefs.getString('saved_phone') ?? '+996555444333');
    try {
      await apiClient.requestOtp(phoneToUse);
      final authResp = await apiClient.verifyOtp(phoneToUse, '0000');
      final newAccess = authResp['access'] as String?;
      final newRefresh = authResp['refresh'] as String?;
      if (newAccess != null) {
        _accessToken = newAccess;
        await prefs.setString('access_token', newAccess);
        if (newRefresh != null) {
          _refreshToken = newRefresh;
          await prefs.setString('refresh_token', newRefresh);
        }
        apiClient.setToken(newAccess);
        return newAccess;
      }
    } catch (e) {
      debugPrint('Auto re-login failed: $e');
    }
    return null;
  }

  Future<void> _initAuth() async {
    isInitializing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.containsKey('cached_is_pro')) {
        _pro = prefs.getBool('cached_is_pro') ?? false;
      }
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');
      // Раньше здесь стоял автоматический вход демо-номером с кодом 0000 —
      // из-за него приложение выглядело работающим без экрана входа. Токена
      // нет — значит пользователь не вошёл, и решает это экран приветствия.
      if (_accessToken != null) {
        apiClient.setToken(_accessToken);
        await fetchProfile();
      }
      if (prefs.containsKey('current_tariff_code')) {
        currentTariffCode = prefs.getString('current_tariff_code') ?? 'owner';
      }
      await fetchTariffs();
      await fetchFilterOptions('bishkek');
      await loadViewHistory();
      await loadFavourites();
    } finally {
      isInitializing = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------- подписки и тарифы
  String currentTariffCode = 'owner';
  List<TariffPlan> tariffs = kDefaultTariffPlans;
  Map<String, dynamic>? currentSubscription;

  TariffPlan get activeTariff => tariffs.firstWhere(
        (t) => t.code == currentTariffCode,
        orElse: () => kDefaultTariffPlans.first,
      );

  Future<void> fetchTariffs() async {
    try {
      final list = await apiClient.getTariffs();
      if (list.isNotEmpty) {
        tariffs = list.map((json) => TariffPlan.fromJson(json)).toList();
      }
    } catch (_) {}
    await fetchCurrentSubscription();
  }

  Future<void> fetchCurrentSubscription() async {
    try {
      final sub = await apiClient.getCurrentSubscription();
      if (sub != null) {
        currentSubscription = sub;
        final tCode = (sub['tariff'] is Map) ? sub['tariff']['code'] : sub['tariff_code'];
        if (tCode != null) {
          final raw = tCode.toString();
          if (raw == 'free') {
            currentTariffCode = 'owner';
          } else if (raw == 'realtor') {
            if (currentTariffCode != 'top' && currentTariffCode != 'vip') {
              currentTariffCode = 'vip';
            }
          } else if (raw == 'agency') {
            currentTariffCode = 'premium';
          } else {
            currentTariffCode = raw;
          }
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('current_tariff_code', currentTariffCode);
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  void spend(int amount, String label) {
    if (walletBalance >= amount) {
      walletBalance -= amount;
    }
    _wallet.insert(
      0,
      WalletEntry(
        day: 'Сегодня',
        label: label,
        bricks: -amount,
        kind: WalletEntryKind.spend,
      ),
    );
    notifyListeners();
  }

  Future<void> buySubscription(TariffPlan tariff, {bool withBricks = false}) async {
    if (tariff.isFree) {
      try {
        await apiClient.cancelSubscription();
      } catch (_) {}
      currentSubscription = null;
    } else {
      // Кирпичи за подписку списывает бэкенд (apps/billing/subscriptions.py).
      // Раньше клиент списывал их ещё раз локально — баланс на экране падал
      // вдвое, пока его не перечитывали с сервера.
      final sub = await apiClient.subscribe(
        tariff.code,
        paymentMethod: withBricks ? 'bricks' : 'som',
      );
      currentSubscription = sub;
      await fetchWalletBalance();
    }

    // Сюда доходим только если сервер подтвердил подписку: ошибка выше
    // пробрасывается вызывающему экрану, а не гасится в debugPrint.
    currentTariffCode = tariff.code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_tariff_code', currentTariffCode);
    notifyListeners();
  }

  Future<void> fetchFilterOptions([String? city = 'bishkek']) async {
    try {
      final citySlug = (city == 'Бишкек' || city == null || city.isEmpty) ? 'bishkek' : city;
      filterOptions = await apiClient.getFilterOptions(city: citySlug);
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to fetch filter options: $e');
    }
  }

  Future<void> fetchProfile() async {
    try {
      final profile = await apiClient.getMe();
      userName = profile['name'] as String?;
      userPhone = profile['phone'] as String?;
      userAvatarUrl = profile['avatar_url'] as String?;
      sellerKind = profile['seller_kind'] as String?;
      if (profile['wallet_balance'] is Map) {
        walletBalance = profile['wallet_balance']['balance'] as int? ?? 0;
      } else {
        walletBalance = profile['wallet_balance'] as int? ?? 0;
      }
      isPro = profile['is_pro'] as bool? ?? false;
      final hasSellerProfile = profile['has_seller_profile'] as bool? ?? false;
      if (isPro || hasSellerProfile || (sellerKind != null && sellerKind!.isNotEmpty)) {
        _pro = true;
      } else {
        _pro = false;
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('cached_is_pro', _pro);
      notifyListeners();
    } catch (e) {
      if (e is ApiException && e.statusCode == 401 && _refreshToken != null) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final data = await apiClient.refreshToken(_refreshToken!);
          final newAccess = data['access'] as String?;
          final newRefresh = data['refresh'] as String?;
          if (newAccess != null) {
            _accessToken = newAccess;
            await prefs.setString('access_token', newAccess);
          }
          if (newRefresh != null) {
            _refreshToken = newRefresh;
            await prefs.setString('refresh_token', newRefresh);
          }
          final profile = await apiClient.getMe();
          userName = profile['name'] as String?;
          userPhone = profile['phone'] as String?;
          userAvatarUrl = profile['avatar_url'] as String?;
          sellerKind = profile['seller_kind'] as String?;
          isPro = profile['is_pro'] as bool? ?? false;
          _pro = isPro || (profile['has_seller_profile'] as bool? ?? false);
          await prefs.setBool('cached_is_pro', _pro);
          notifyListeners();
          return;
        } catch (_) {
          await logout();
        }
      }
      debugPrint('Failed to fetch profile: $e');
    }
  }

  /// Подпись роли под именем в профиле: «Клиент» или тип продавца.
  String get roleLabel {
    if (!(pro || isPro)) return 'Клиент';
    switch (sellerKind) {
      case 'owner':
        return 'Собственник';
      case 'realtor':
        return 'Риелтор';
      case 'agency':
        return 'Агентство';
      default:
        return 'Исполнитель';
    }
  }

  /// Инициалы для заглушки аватара, когда фото не загружено.
  String get userInitials {
    final parts = (userName ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '';
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }

  /// Сохраняет имя пользователя на сервере (PATCH /users/me/).
  Future<void> updateProfileName(String name) async {
    final response = await apiClient.updateMe({'name': name});
    userName = response['name'] as String? ?? name;
    notifyListeners();
  }

  Future<void> fetchWalletBalance() async {
    try {
      final response = await apiClient.getWalletBalance();
      walletBalance = response['balance'] as int? ?? 0;
      _bricks = walletBalance;
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
    userAvatarUrl = null;
    sellerKind = null;
    walletBalance = 0;
    isPro = false;
    _pro = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_is_pro');
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    
    _favourites.clear();
    _viewed.clear();
    _query = '';

    apiClient.setToken(null);
    notifyListeners();
  }

  /// Версия соглашения об обработке ПДн, которую сейчас требует сервер.
  ///
  /// Пусто — соглашения на сервере нет, и регистрировать никого нельзя:
  /// принять документ, которого не существует, невозможно.
  String? termsVersion;

  /// Адрес текста соглашения — на него ведёт ссылка из галки согласия.
  String? termsUrl;

  /// Забирает версию и ссылку на соглашение из /app/config/.
  Future<void> loadTermsDocument() async {
    final config = await apiClient.getAppConfig();
    final documents = config['documents'];
    final terms = documents is Map ? documents['terms'] : null;
    if (terms is Map) {
      termsVersion = terms['version']?.toString();
      termsUrl = terms['url']?.toString();
    } else {
      termsVersion = null;
      termsUrl = null;
    }
    notifyListeners();
  }

  Future<void> sendOtp(String phone, {String? purpose}) async {
    await apiClient.requestOtp(phone, purpose: purpose);
  }

  /// Первый шаг регистрации: высылает код на номер.
  ///
  /// Аккаунт здесь не создаётся и пароль никуда не сохраняется — до ввода
  /// кода мы не знаем, принадлежит ли номер тому, кто его вписал.
  Future<void> startRegistration(String phone) async {
    await apiClient.requestOtp(phone, purpose: 'register');
  }

  /// Второй шаг: код подтверждён — заводим аккаунт с именем и паролем.
  Future<void> confirmRegistration({
    required String phone,
    required String code,
    required String name,
    required String password,
    required String termsVersion,
  }) async {
    final response = await apiClient.verifyOtp(
      phone,
      code,
      name: name,
      password: password,
      purpose: 'register',
      termsVersion: termsVersion,
    );
    await _saveTokens(response);
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
    final prefs = await SharedPreferences.getInstance();
    if (response.containsKey('access') && response['access'] != null) {
      _accessToken = response['access'] as String;
      apiClient.setToken(_accessToken);
      await prefs.setString('access_token', _accessToken!);
    }
    if (response.containsKey('refresh') && response['refresh'] != null) {
      _refreshToken = response['refresh'] as String;
      await prefs.setString('refresh_token', _refreshToken!);
    }
    if (response.containsKey('user') && response['user'] is Map) {
      final user = response['user'] as Map<String, dynamic>;
      userName = user['name'] as String?;
      userPhone = user['phone'] as String?;
      userAvatarUrl = user['avatar_url'] as String?;
      sellerKind = user['seller_kind'] as String?;
      if (userPhone != null && userPhone!.isNotEmpty) {
        await prefs.setString('saved_phone', userPhone!);
      }
      isPro = user['is_pro'] as bool? ?? false;
      final hasSeller = user['has_seller_profile'] as bool? ?? false;
      if (isPro || hasSeller || (sellerKind != null && sellerKind!.isNotEmpty)) {
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

  Future<void> loadFavourites() async {
    try {
      final resp = await apiClient.getFavourites();
      final results = resp['results'] as List<dynamic>? ?? [];
      bool changed = false;
      for (final item in results) {
        if (item is Map) {
          final slug = item['slug']?.toString() ?? item['id']?.toString();
          if (slug != null && slug.isNotEmpty && !_favourites.contains(slug)) {
            _favourites.add(slug);
            changed = true;
          }
        }
      }
      if (changed) notifyListeners();
    } catch (e) {
      print('Failed to load favourites: $e');
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
      final isFavourited = response['is_favourite'] == true || response['is_favourited'] == true;
      
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
  final Set<String> _plotPurposes = {};
  final Set<String> _commercialPurposes = {};
  final Set<String> _buildingLines = {};
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
  bool get series103 => _series103;
  Set<String> get series => Set.unmodifiable(_series);
  Set<String> get plotPurposes => Set.unmodifiable(_plotPurposes);
  Set<String> get commercialPurposes => Set.unmodifiable(_commercialPurposes);
  Set<String> get buildingLines => Set.unmodifiable(_buildingLines);

  void togglePlotPurpose(String value) {
    _plotPurposes.contains(value) ? _plotPurposes.remove(value) : _plotPurposes.add(value);
    notifyListeners();
  }

  void toggleCommercialPurpose(String value) {
    _commercialPurposes.contains(value)
        ? _commercialPurposes.remove(value)
        : _commercialPurposes.add(value);
    notifyListeners();
  }

  void toggleBuildingLine(String value) {
    _buildingLines.contains(value) ? _buildingLines.remove(value) : _buildingLines.add(value);
    notifyListeners();
  }
  int? get priceFrom => _priceFrom;
  int? get priceTo => _priceTo;
  bool get ownerOnly => _sellers.contains(SellerKind.owner);

  void setSeries103(bool value) {
    if (_series103 == value) return;
    _series103 = value;
    notifyListeners();
  }

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
    if (_plotPurposes.isNotEmpty) params['plot_purpose'] = _plotPurposes.join(',');
    if (_commercialPurposes.isNotEmpty) {
      params['commercial_purpose'] = _commercialPurposes.join(',');
    }
    if (_buildingLines.isNotEmpty) params['building_line'] = _buildingLines.join(',');
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

  // ------------------------------------------------------------ пополнение
  //
  // Счёт выставляет бэкенд, деньги подтверждает вебхук платёжного шлюза.
  // Клиент только показывает ссылку/QR и опрашивает статус: «подтвердить»
  // оплату из приложения нельзя — иначе баланс рисовался бы сам себе.

  TopupIntent? currentTopup;
  bool isTopupLoading = false;
  String? topupError;

  /// Выставляет счёт на пополнение. Ключ идемпотентности живёт вместе со
  /// счётом: повтор того же шага не создаёт второй счёт.
  Future<TopupIntent> createTopup(int amount) async {
    isTopupLoading = true;
    topupError = null;
    setTopupAmount(amount);
    notifyListeners();

    try {
      final response = await apiClient.createTopup(
        amountKgs: amount,
        idempotencyKey: const Uuid().v4(),
      );
      final intent = TopupIntent.fromJson(response);
      currentTopup = intent;
      return intent;
    } catch (e) {
      topupError = _topupErrorText(e);
      rethrow;
    } finally {
      isTopupLoading = false;
      notifyListeners();
    }
  }

  /// Разовый запрос статуса счёта.
  Future<TopupStatusResult> fetchTopupStatus(String paymentId) async {
    final response = await apiClient.getTopupStatus(paymentId);
    final result = TopupStatusResult.fromJson(response);

    walletBalance = result.balance;
    _bricks = result.balance;
    notifyListeners();
    return result;
  }

  /// Опрашивает статус, пока счёт не станет окончательным или не выйдет время.
  ///
  /// Возвращает последний известный статус. Сетевые сбои внутри опроса не
  /// прерывают ожидание — оплата могла пройти, просто ответ не дошёл.
  Future<TopupStatusResult> waitForTopup(
    String paymentId, {
    Duration timeout = const Duration(minutes: 10),
    Duration interval = const Duration(seconds: 3),
    bool Function()? isCancelled,
  }) async {
    final deadline = DateTime.now().add(timeout);
    TopupStatusResult last = const TopupStatusResult(
      status: TopupStatus.pending,
      balance: 0,
      creditedBricks: 0,
    );

    while (DateTime.now().isBefore(deadline)) {
      if (isCancelled?.call() ?? false) return last;

      try {
        last = await fetchTopupStatus(paymentId);
        if (last.status.isFinal) return last;
      } catch (e) {
        debugPrint('Опрос статуса пополнения не удался: $e');
      }

      await Future<void>.delayed(interval);
    }

    return last;
  }

  void resetTopup() {
    currentTopup = null;
    topupError = null;
    isTopupLoading = false;
    notifyListeners();
  }

  String _topupErrorText(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 401) return 'Войдите в аккаунт, чтобы пополнить кошелёк';
      if (error.statusCode == 429) {
        return 'Слишком много счетов подряд. Подождите немного и повторите';
      }
      // Чаще всего это незаполненные ключи Finik на сервере: провайдер
      // отказывается выставлять счёт, и вьюха отдаёт server_error. Показывать
      // пользователю голое «500» бессмысленно — он ничего с ним не сделает.
      if (error.statusCode >= 500) {
        return 'Оплата через Finik сейчас недоступна. Попробуйте позже';
      }
      return error.message;
    }
    if (error is NetworkException) return 'Нет связи с сервером. Проверьте интернет';
    return 'Не удалось выставить счёт на оплату';
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
  // История просмотров подгружается из бэкенда.
  final List<ViewEntry> _viewed = [];

  List<ViewEntry> get viewed => List.unmodifiable(_viewed);
  bool isHistoryLoading = false;

  Future<void> loadViewHistory() async {
    isHistoryLoading = true;
    notifyListeners();
    try {
      final data = await apiClient.getViewHistory();
      final results = data['results'] as List<dynamic>? ?? [];
      final entries = <ViewEntry>[];
      for (final group in results) {
        if (group is Map) {
          final items = group['items'] as List<dynamic>? ?? [];
          for (final item in items) {
            if (item is Map) {
              final listingMap = Map<String, dynamic>.from(item);
              final listing = Listing.fromJson(listingMap);
              final viewedAtStr = listingMap['viewed_at'] as String?;
              final at = viewedAtStr != null
                  ? (DateTime.tryParse(viewedAtStr)?.toLocal() ?? DateTime.now())
                  : DateTime.now();
              entries.add(ViewEntry(listing.id, at, listingData: listing));
            }
          }
        }
      }
      _viewed.clear();
      _viewed.addAll(entries);
    } catch (e) {
      print('Failed to load view history: $e');
    } finally {
      isHistoryLoading = false;
      notifyListeners();
    }
  }

  /// Объект открыли — он поднимается наверх истории с текущим временем и отправляется на бэкенд.
  void noteViewed(String id, {Listing? listing}) {
    _viewed.removeWhere((e) => e.id == id);
    _viewed.insert(0, ViewEntry(id, DateTime.now(), listingData: listing));
    notifyListeners();
    apiClient.recordListingView(id);
  }

  Future<void> forgetViewed(Set<String> ids) async {
    if (ids.isEmpty) return;
    _viewed.removeWhere((e) => ids.contains(e.id));
    notifyListeners();
    try {
      await apiClient.clearViewHistory(slugs: ids.toList());
    } catch (e) {
      print('Failed to forget viewed items: $e');
    }
  }

  Future<void> clearAllViewed() async {
    _viewed.clear();
    notifyListeners();
    try {
      await apiClient.clearViewHistory(all: true);
    } catch (e) {
      print('Failed to clear view history: $e');
    }
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
  String draftLandArea = '';
  String draftPlotPurpose = '';
  String draftCommercialPurpose = '';
  bool draftSeparateEntrance = false;
  String draftBuildingLine = '';
  String draftCeilingHeight = '';
  String draftAddress = '';
  String draftDescription = '';
  String draftSeries = '';
  bool draftSecondary = false;
  String draftFurniture = '';
  String draftCondition = '';
  String draftHeating = '';
  bool draftHasGas = false;
  bool draftExchange = false;
  bool draftDirectSale = true;
  bool draftMortgage = true;
  String draftContactName = '';
  String draftContactPhone = '';
  final List<String> draftLandmarks = [];
  /// Экспликация помещений черновика: владелец сам решает, какие комнаты
  /// добавить. Фиксированного набора нет.
  final List<DraftRoom> draftRoomList = [];
  String draftPrice = '';
  bool draftUsd = true;
  bool draftOwner = true;
  bool draftAllowDownload = true;
  bool draftUseAdInfo = true;
  String? draftSlug;

  /// Сколько файлов принимает объявление — столько же обещает и подпись под
  /// кнопкой «Добавить».
  static const int draftMediaLimit = 20;

  final List<AdMedia> draftGallery = [];
  final List<AdMedia> draftVideoList = [];

  /// Смена типа объявления: значения полей, неприменимых к новому типу,
  /// забываются — иначе на сервер уедет `rooms` от предыдущего выбора.
  void setDraftKind(PropertyKind kind) {
    draftKinds
      ..clear()
      ..add(kind);

    if (!showsField(kind, ListingField.rooms)) draftRooms = 0;
    if (!showsField(kind, ListingField.floor)) draftFloor = 0;
    if (!showsField(kind, ListingField.floors)) draftFloors = 0;
    if (!showsField(kind, ListingField.builder)) draftBuilder = '';
    if (!showsField(kind, ListingField.landArea)) draftLandArea = '';
    if (!showsField(kind, ListingField.plotPurpose)) draftPlotPurpose = '';
    if (!showsField(kind, ListingField.commercialPurpose)) {
      draftCommercialPurpose = '';
      draftSeparateEntrance = false;
      draftBuildingLine = '';
      draftCeilingHeight = '';
    }
    if (!showsField(kind, ListingField.series)) draftSeries = '';
    if (!showsField(kind, ListingField.isSecondary)) draftSecondary = false;
    if (!showsField(kind, ListingField.interior)) {
      draftFurniture = '';
      draftCondition = '';
      draftHeating = '';
      draftHasGas = false;
      draftRoomList.clear();
    }
    notifyListeners();
  }

  int get draftPhotos => draftGallery.length;
  int get draftVideos => draftVideoList.length;

  /// Сколько ещё влезет — по нему кнопка «Добавить» гаснет.
  int get freePhotoSlots => draftMediaLimit - draftGallery.length;
  int get freeVideoSlots => draftMediaLimit - draftVideoList.length;

  /// Загрузить черновик с бэкенда
  Future<void> loadDraft() async {
    try {
      final response = await apiClient.getDraft();
      draftSlug = response['slug'] as String?;
      if (response['kind'] != null) {
        final kindStr = (response['kind'] as String).replaceAll('-', '_');
        final kind = PropertyKind.values.firstWhere(
          (k) => propertyKindCode(k) == kindStr || k.name == kindStr,
          orElse: () => PropertyKind.apartment,
        );
        draftKinds.clear();
        draftKinds.add(kind);
      }
      if (response['rooms'] != null) draftRooms = response['rooms'] as int;
      if (response['floor'] != null) draftFloor = response['floor'] as int;
      if (response['floors'] != null) draftFloors = response['floors'] as int;
      if (response['area'] != null) draftArea = response['area'].toString();
      if (response['land_area'] != null) draftLandArea = response['land_area'].toString();
      draftPlotPurpose = response['plot_purpose'] as String? ?? '';
      draftCommercialPurpose = response['commercial_purpose'] as String? ?? '';
      draftSeparateEntrance = response['has_separate_entrance'] as bool? ?? false;
      draftBuildingLine = response['building_line'] as String? ?? '';
      if (response['ceiling_height'] != null) {
        draftCeilingHeight = response['ceiling_height'].toString();
      }
      if (response['price'] != null) {
        final rawPrice = response['price'];
        if (rawPrice is num) {
          draftPrice = rawPrice % 1 == 0 ? rawPrice.toInt().toString() : rawPrice.toString();
        } else {
          final pStr = rawPrice.toString();
          final parsed = double.tryParse(pStr.replaceAll(' ', '').replaceAll(',', '.'));
          if (parsed != null) {
            draftPrice = parsed % 1 == 0 ? parsed.toInt().toString() : parsed.toString();
          } else {
            draftPrice = pStr;
          }
        }
      }
      draftAddress = response['address'] as String? ?? '';
      draftDescription = response['description'] as String? ?? '';
      draftSecondary = response['is_secondary'] as bool? ?? false;
      draftFurniture = response['furniture'] as String? ?? '';
      draftCondition = response['condition'] as String? ?? '';
      draftHeating = response['heating'] as String? ?? '';
      draftHasGas = response['has_gas'] as bool? ?? false;
      draftExchange = response['exchange_possible'] as bool? ?? false;
      draftDirectSale = response['has_direct_sale'] as bool? ?? true;
      draftMortgage = response['has_mortgage'] as bool? ?? true;
      draftContactName = response['contact_name'] as String? ?? '';
      draftContactPhone = response['contact_phone'] as String? ?? '';
      draftLandmarks
        ..clear()
        ..addAll((response['landmarks'] as List<dynamic>? ?? const [])
            .map((e) => e.toString()));
      draftRoomList
        ..clear()
        ..addAll((response['rooms_breakdown'] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map((m) => DraftRoom(
                  name: (m['name'] ?? '').toString(),
                  area: (m['area'] ?? '').toString(),
                )));
      if (response['series'] != null) {
        final series = response['series'];
        draftSeries = series is Map ? (series['code'] ?? '').toString() : series.toString();
      }
      if (response['currency'] != null) draftUsd = response['currency'] == 'USD';
      if (response['district'] != null) {
        final d = response['district'];
        draftDistrict = d is Map ? (d['slug'] ?? d['id']?.toString() ?? '') : d.toString();
      }
      if (response['builder'] != null) {
        final b = response['builder'];
        draftBuilder = b is Map ? (b['name'] ?? '') : b.toString();
      }
      if (response['allow_media_download'] != null) {
        draftAllowDownload = response['allow_media_download'] as bool;
      }
      final mediaList = response['media'] as List<dynamic>?;
      if (mediaList != null) {
        draftGallery.clear();
        draftVideoList.clear();
        for (final m in mediaList) {
          final kind = m['kind'] as String?;
          final fileUrl = m['file'] as String? ?? m['url'] as String? ?? '';
          final mediaId = m['id'] as int?;
          if (kind == 'video') {
            draftVideoList.add(AdMedia.network(
              fileUrl,
              id: mediaId,
              video: true,
              title: m['title'] as String?,
              description: m['description'] as String?,
            ));
          } else {
            draftGallery.add(AdMedia.network(
              fileUrl,
              id: mediaId,
              video: false,
            ));
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('loadDraft error: $e');
    }
  }

  void resetDraft() {
    draftKinds.clear();
    draftKinds.add(PropertyKind.newBuilding);
    draftRooms = 1;
    draftFloor = 1;
    draftFloors = 1;
    draftArea = '';
    draftDistrict = 'Район Бишкека';
    draftBuilder = '';
    draftPrice = '';
    draftUsd = true;
    draftOwner = true;
    draftAllowDownload = true;
    draftUseAdInfo = true;
    draftSlug = null;
    draftGallery.clear();
    draftVideoList.clear();
    notifyListeners();
  }

  /// Выбрать снимки. Возвращает, сколько добавилось.
  Future<int> addPhotos({required bool camera}) async {
    final picked = await _media.photos(camera: camera);
    return _append(draftGallery, picked);
  }

  /// Выбрать ролик.
  ///
  /// Файл появляется в списке сразу, а кадр-обложка догоняет отдельно: съёмка
  /// кадра занимает секунды и на битом файле может не выйти вовсе — ждать её
  /// значило бы, что выбранный ролик просто не появляется на экране.
  Future<int> addVideo({required bool camera}) async {
    final picked = await _media.video(camera: camera);
    final added = _append(draftVideoList, [if (picked != null) picked]);

    final path = picked?.path;
    if (added > 0 && path != null && path.isNotEmpty) {
      unawaited(_attachPoster(path));
    }
    return added;
  }

  /// Дописывает кадр и метаданные ролика, когда они готовы.
  Future<void> _attachPoster(String path) async {
    try {
      final poster = await _posterCapture(path);
      if (poster.isEmpty) return;

      final index = draftVideoList.indexWhere((item) => item.path == path);
      if (index < 0) return;

      draftVideoList[index] = draftVideoList[index].withPoster(poster);
      notifyListeners();
    } catch (e) {
      debugPrint('Обложка ролика не снялась: $e');
    }
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
    if (media.id != null && draftSlug != null) {
      apiClient.deleteMedia(draftSlug!, media.id!).catchError((e) {
        debugPrint('Failed to delete media from backend: $e');
      });
    }
    notifyListeners();
  }

  /// Продвижение: сколько дней и чем платим.
  int promoDays = 1;
  bool promoFromBalance = false;
  /// Цена дня продвижения для предпросмотра. Настоящую цену считает бэкенд
  /// (`GET /promotions/pricing/`), здесь — то же число, что стоит в базе.
  /// Тестовый режим оплаты: один кирпич за день (боевая цена — 780).
  static const int promoPricePerDay = 1;

  int get promoCost => promoDays * promoPricePerDay;

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

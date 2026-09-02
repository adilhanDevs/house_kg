import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/chat_controller.dart' show describeApiError;
import '../../data/listings.dart';
import '../../l10n/app_localizations.dart';
import '../app_tab_bar.dart';
import '../fig_cta.dart';
import '../object_card.dart';
import '../widgets/safe_image.dart';
import 'chat_page.dart';

@immutable
class AgentListingsArgs {
  const AgentListingsArgs({
    this.sellerId = 0,
    this.initialListingSlug,
    this.initialListingTitle,
    this.initialSellerName,
    this.initialSellerKind,
    this.initialAvatarUrl,
    this.initialCoverUrl,
  });

  final int sellerId;
  final String? initialListingSlug;
  final String? initialListingTitle;
  final String? initialSellerName;
  final String? initialSellerKind;
  final String? initialAvatarUrl;
  final String? initialCoverUrl;
}

class AgentListingsPage extends StatefulWidget {
  const AgentListingsPage({super.key, this.args});

  final AgentListingsArgs? args;

  @override
  State<AgentListingsPage> createState() => _AgentListingsPageState();
}

class _AgentListingsPageState extends State<AgentListingsPage> {
  PublicSellerProfile? _seller;
  bool _isLoadingSeller = true;

  String? _selectedKind;
  List<Listing> _listings = [];
  bool _isLoadingListings = true;
  String? _listingsCursor;
  bool _hasMoreListings = false;
  bool _isLoadingMore = false;
  String? _listingsError;

  bool _isOpeningChat = false;
  final ScrollController _scrollController = ScrollController();

  int get _sellerId => widget.args?.sellerId ?? 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_hasMoreListings && !_isLoadingMore && !_isLoadingListings) {
        _loadMoreListings();
      }
    }
  }

  Future<void> _loadData() async {
    await Future.wait([_loadSellerProfile(), _loadListings(refresh: true)]);
  }

  Future<void> _loadSellerProfile() async {
    if (!mounted) return;
    final state = AppScope.read(context);

    if (_sellerId <= 0) {
      setState(() {
        _isLoadingSeller = false;
      });
      return;
    }

    setState(() {
      _isLoadingSeller = true;
    });

    try {
      final json = await state.apiClient.getSeller(_sellerId);
      if (!mounted) return;
      setState(() {
        _seller = PublicSellerProfile.fromJson(json);
        _isLoadingSeller = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingSeller = false;
      });
    }
  }

  Future<void> _loadListings({bool refresh = false}) async {
    if (!mounted) return;
    final state = AppScope.read(context);

    if (refresh) {
      setState(() {
        _isLoadingListings = true;
        _listingsError = null;
        _listingsCursor = null;
        _hasMoreListings = false;
      });
    }

    // Без продавца показывать демонстрационный каталог нельзя: на экране
    // появлялись чужие объявления под именем «Продавец», а кнопка связи потом
    // не находила, о чём писать. Честнее сказать, что продавец не определён.
    if (_sellerId <= 0) {
      setState(() {
        _listings = [];
        _isLoadingListings = false;
        _listingsError = AppLocalizations.of(context).sellerNotFound;
      });
      return;
    }

    try {
      final json = await state.apiClient.getSellerListings(
        _sellerId,
        cursor: _listingsCursor,
        kind: _selectedKind,
        pageSize: 20,
      );
      if (!mounted) return;

      final results = (json['results'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((m) => Listing.fromJson(m))
          .toList();

      final nextCursor = json['next'] as String?;

      setState(() {
        if (refresh) {
          _listings = results;
        } else {
          _listings.addAll(results);
        }
        _listingsCursor = nextCursor;
        _hasMoreListings = nextCursor != null && nextCursor.isNotEmpty;
        _isLoadingListings = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _listingsError = describeApiError(e);
        _isLoadingListings = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreListings() async {
    if (_isLoadingMore || !_hasMoreListings || _listingsCursor == null) return;
    setState(() => _isLoadingMore = true);
    await _loadListings(refresh: false);
  }

  void _onKindSelected(String? kind) {
    if (_selectedKind == kind) return;
    setState(() {
      _selectedKind = kind;
    });
    _loadListings(refresh: true);
  }

  Future<void> _onContactPressed() async {
    if (_isOpeningChat) return;

    final state = AppScope.read(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);

    if (!state.isAuthenticated) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sellerMustLoginToWrite)),
      );
      navigator.pushNamed(Routes.welcome);
      return;
    }

    final currentUserId = state.userId;
    if (currentUserId != null &&
        ((_seller != null && currentUserId == _seller!.id) ||
            (_sellerId > 0 && currentUserId == _sellerId))) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.sellerThisIsYou)));
      return;
    }

    final slug =
        widget.args?.initialListingSlug ??
        (_listings.isNotEmpty ? _listings.first.slug : '');

    if (slug.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sellerNoListingToDiscuss)),
      );
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      final data = await state.apiClient.openConversation(slug);
      if (!mounted) return;
      final conversationId = data['id']?.toString() ?? '';
      final title =
          widget.args?.initialListingTitle ??
          (_listings.isNotEmpty
              ? _listings.first.address
              : (_seller?.displayName ?? ''));

      navigator.pushNamed(
        Routes.conversation,
        arguments: ChatArgs(conversationId, listingTitle: title),
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(describeApiError(e))));
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningChat = false);
      }
    }
  }

  String _getContactLabel(AppLocalizations l10n) {
    final kind =
        _seller?.sellerKind ?? widget.args?.initialSellerKind ?? 'owner';
    switch (kind) {
      case 'owner':
        return l10n.contactOwner;
      case 'realtor':
        return l10n.contactRealtor;
      case 'agency':
        return l10n.contactAgency;
      default:
        return l10n.contactSeller;
    }
  }

  String _getRoleName(String kind, AppLocalizations l10n) {
    switch (kind) {
      case 'realtor':
        return l10n.roleRealtor;
      case 'agency':
        return l10n.roleAgency;
      case 'owner':
      default:
        return l10n.roleOwner;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = AppLocalizations.of(context);

    final coverUrl = _seller?.coverUrl ?? widget.args?.initialCoverUrl;
    final avatarUrl = _seller?.avatarUrl ?? widget.args?.initialAvatarUrl;
    final sellerName =
        _seller?.displayName ??
        widget.args?.initialSellerName ??
        (_isLoadingSeller ? '' : 'Продавец');
    final sellerKind =
        _seller?.sellerKind ?? widget.args?.initialSellerKind ?? 'owner';
    final isVerified = _seller?.isVerified ?? false;
    final activeCount = _seller?.activeListingsCount ?? _listings.length;
    final soldCount = _seller?.soldListingsCount ?? 0;

    final filterTabs = <MapEntry<String?, String>>[
      MapEntry(null, l10n.all),
      MapEntry('new_building', l10n.kindNewBuilding),
      MapEntry('apartment', l10n.kindApartment),
      MapEntry('commercial', l10n.kindCommercial),
      MapEntry('house', l10n.kindHouse),
      MapEntry('plot', l10n.kindPlot),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final coverHeight = (width * 0.545).clamp(196.0, 260.0).toDouble();
    final avatarSize = (width * 0.174).clamp(64.0, 76.0).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xffea812e),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Обложка и шапка — один слайвер: аватар наполовину выходит за
            // край обложки, а на границе двух слайверов этот выступ
            // подрезался, и аватар был виден лишь наполовину.
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildCover(coverUrl, coverHeight, l10n),
                  _buildSellerHeader(
                    avatarUrl: avatarUrl,
                    avatarSize: avatarSize,
                    sellerName: sellerName,
                    sellerKind: sellerKind,
                    isVerified: isVerified,
                    activeCount: activeCount,
                    soldCount: soldCount,
                    l10n: l10n,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(child: _buildFilterTabs(filterTabs)),
            _buildListingsSliver(state, l10n),
            if (_isLoadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(Color(0xffea812e)),
                    ),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        key: const ValueKey('agent-bottom-chrome'),
        color: const Color(0xffffffff),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FigCta(
              label: _isOpeningChat ? 'Загрузка...' : _getContactLabel(l10n),
              onTap: _isOpeningChat ? null : _onContactPressed,
            ),
            const AppTabBar(active: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildCover(
    String? coverUrl,
    double coverHeight,
    AppLocalizations l10n,
  ) {
    return SizedBox(
      key: const ValueKey('agent-cover'),
      height: coverHeight,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null && coverUrl.isNotEmpty)
              buildSafeNetworkImage(
                url: coverUrl,
                fit: BoxFit.cover,
                fallback: _buildDefaultCover(),
              )
            else
              _buildDefaultCover(),
            Positioned(
              left: 17,
              top: MediaQuery.paddingOf(context).top + 12,
              child: Semantics(
                button: true,
                label: l10n.back,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    } else {
                      Navigator.pushReplacementNamed(context, Routes.home);
                    }
                  },
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0x73000000),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerHeader({
    required String? avatarUrl,
    required double avatarSize,
    required String sellerName,
    required String sellerKind,
    required bool isVerified,
    required int activeCount,
    required int soldCount,
    required AppLocalizations l10n,
  }) {
    const statsStyle = TextStyle(
      fontSize: 15,
      height: 1.25,
      fontWeight: FontWeight.w500,
      color: Color(0xff858585),
    );
    final about = _seller?.about;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(top: avatarSize / 2 + 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        sellerName.isNotEmpty ? sellerName : '...',
                        key: const ValueKey('agent-profile-heading'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.08,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff000000),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _buildRoleBadge(sellerKind, l10n),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(l10n.sellerObjectsCount(activeCount), style: statsStyle),
                if (soldCount > 0) ...[
                  const SizedBox(height: 1),
                  Text(l10n.sellerSoldCount(soldCount), style: statsStyle),
                ],
                if (about != null && about.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    about,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Color(0xff4b5563),
                    ),
                  ),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: -avatarSize / 2,
            child: SizedBox(
              key: const ValueKey('agent-avatar'),
              width: avatarSize,
              height: avatarSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white, width: 3),
                      color: const Color(0xfffdf1e8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? buildSafeNetworkImage(
                              url: avatarUrl,
                              fit: BoxFit.cover,
                              fallback: _avatarPlaceholder(avatarSize),
                            )
                          : _avatarPlaceholder(avatarSize),
                    ),
                  ),
                  if (isVerified)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xff188038),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(List<MapEntry<String?, String>> filterTabs) {
    return SizedBox(
      key: const ValueKey('agent-filter-tabs'),
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 25),
        itemCount: filterTabs.length,
        separatorBuilder: (context, index) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final tab = filterTabs[index];
          final isSelected = _selectedKind == tab.key;
          return GestureDetector(
            onTap: () => _onKindSelected(tab.key),
            child: Container(
              key: ValueKey('agent-filter-${tab.key ?? 'all'}'),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xffffeadb)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  tab.value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xffea812e)
                        : const Color(0xffb8b8ba),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListingsSliver(AppState state, AppLocalizations l10n) {
    if (_isLoadingListings) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Color(0xffea812e)),
            ),
          ),
        ),
      );
    }

    if (_listingsError != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Color(0xffea812e),
                ),
                const SizedBox(height: 12),
                Text(
                  _listingsError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xff555555),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _loadListings(refresh: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xffea812e),
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n.tryAgain),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_listings.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              l10n.sellerNoListings,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xff8e8e93)),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      key: const ValueKey('agent-listings-grid'),
      padding: const EdgeInsets.fromLTRB(25, 16, 25, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 5,
          mainAxisSpacing: 24,
          // Те же пропорции, что на главном экране: выше карточка становилась
          // слишком крупной, а подписи под ценой налезали друг на друга.
          childAspectRatio: kCardWidth / kCardHeight,
        ),
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          final listing = _listings[index];
          final listingKey = listing.slug.isNotEmpty
              ? listing.slug
              : listing.id;
          return ObjectCard(
            listing: listing,
            favourite: state.isFavourite(listingKey),
            adaptive: true,
            onTap: () {
              Navigator.of(
                context,
              ).pushNamed(Routes.listing, arguments: listing);
            },
            onFavourite: () => state.toggleFavourite(listingKey),
          );
        },
      ),
    );
  }

  /// Заглушка аватара — та же, что в профиле: персиковый фон, оранжевая фигура.
  Widget _avatarPlaceholder(double size) {
    return Container(
      color: const Color(0xfffdf1e8),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        size: size * 0.5,
        color: const Color(0xffea812e),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      // Та же заглушка, что в профиле: тёмно-серая полоса выглядела ошибкой
      // загрузки, хотя фото просто нет.
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xfff7931e), Color(0xffea812e), Color(0xffcb6015)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.photo_outlined, color: Colors.white70, size: 36),
      ),
    );
  }

  Widget _buildRoleBadge(String kind, AppLocalizations l10n) {
    Color bg;
    Color fg;
    switch (kind) {
      case 'realtor':
        bg = const Color(0xfffff4e8);
        fg = const Color(0xffea812e);
        break;
      case 'agency':
        bg = const Color(0xffe6f4ea);
        fg = const Color(0xff188038);
        break;
      case 'owner':
      default:
        bg = const Color(0xffe8f1ff);
        fg = const Color(0xff0066ff);
        break;
    }

    return Container(
      key: const ValueKey('agent-role-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getRoleName(kind, l10n),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

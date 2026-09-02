import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../app/stage.dart';
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
    await Future.wait([
      _loadSellerProfile(),
      _loadListings(refresh: true),
    ]);
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

    if (_sellerId <= 0) {
      final local = kListings.where((l) {
        if (_selectedKind == null) return true;
        return l.kind.name == _selectedKind ||
            (_selectedKind == 'new_building' && l.kind == PropertyKind.newBuilding);
      }).toList();
      setState(() {
        _listings = local;
        _isLoadingListings = false;
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
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.sellerThisIsYou)),
      );
      return;
    }

    final slug = widget.args?.initialListingSlug ??
        (_listings.isNotEmpty ? _listings.first.slug : '');

    if (slug.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.empty)),
      );
      return;
    }

    setState(() => _isOpeningChat = true);
    try {
      final data = await state.apiClient.openConversation(slug);
      if (!mounted) return;
      final conversationId = data['id']?.toString() ?? '';
      final title = widget.args?.initialListingTitle ??
          (_listings.isNotEmpty ? _listings.first.address : (_seller?.displayName ?? ''));

      navigator.pushNamed(
        Routes.conversation,
        arguments: ChatArgs(
          conversationId,
          listingTitle: title,
        ),
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
    final kind = _seller?.sellerKind ?? widget.args?.initialSellerKind ?? 'owner';
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
    final sellerName = _seller?.displayName ??
        widget.args?.initialSellerName ??
        (_isLoadingSeller ? '' : 'Продавец');
    final sellerKind = _seller?.sellerKind ?? widget.args?.initialSellerKind ?? 'owner';
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

    return Scaffold(
      backgroundColor: const Color(0xffffffff),
      body: Stack(
        children: [
          // Scrollable content
          RefreshIndicator(
            onRefresh: _loadData,
            color: const Color(0xffea812e),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cover with back button
                  SizedBox(
                    height: 221,
                    width: double.infinity,
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
                          top: 40,
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
                                width: 32,
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: Color(0x73000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.arrow_back_ios_new,
                                    size: 15,
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

                  // Seller Info Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -37),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 74,
                                height: 74,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                  color: const Color(0xfff0f0f0),
                                ),
                                child: ClipOval(
                                  child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                      ? buildSafeNetworkImage(
                                          url: avatarUrl,
                                          fit: BoxFit.cover,
                                          fallback: const Icon(
                                            Icons.person,
                                            size: 40,
                                            color: Color(0xff8e8e93),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Color(0xff8e8e93),
                                        ),
                                ),
                              ),
                              if (isVerified)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff188038),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.check, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Transform.translate(
                          offset: const Offset(0, -25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sellerName.isNotEmpty ? sellerName : '...',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xff000000),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _buildRoleBadge(sellerKind, l10n),
                              const SizedBox(height: 10),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    l10n.sellerObjectsCount(activeCount),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xff555555),
                                    ),
                                  ),
                                  if (soldCount > 0) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Text(
                                        '•',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xffd9d9d9),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      l10n.sellerSoldCount(soldCount),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xff555555),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (_seller?.about != null && _seller!.about.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _seller!.about,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Color(0xff4b5563),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Category Tabs
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      itemCount: filterTabs.length,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final tab = filterTabs[index];
                        final isSelected = _selectedKind == tab.key;
                        return GestureDetector(
                          onTap: () => _onKindSelected(tab.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xff1f2937)
                                  : const Color(0xfff3f4f6),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Center(
                              child: Text(
                                tab.value,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xffffffff)
                                      : const Color(0xff4b5563),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Listings Grid / States
                  if (_isLoadingListings)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xffea812e)),
                        ),
                      ),
                    )
                  else if (_listingsError != null)
                    Padding(
                      padding: const EdgeInsets.all(25.0),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 48, color: Color(0xffea812e)),
                            const SizedBox(height: 12),
                            Text(
                              _listingsError!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, color: Color(0xff555555)),
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
                    )
                  else if (_listings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Center(
                        child: Text(
                          l10n.sellerNoListings,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14, color: Color(0xff8e8e93)),
                        ),
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 5.0,
                          mainAxisSpacing: 24.0,
                          childAspectRatio: kCardWidth / kCardHeight,
                        ),
                        itemCount: _listings.length,
                        itemBuilder: (context, index) {
                          final listing = _listings[index];
                          final isFav = state.isFavourite(listing.slug.isNotEmpty ? listing.slug : listing.id);
                          return ObjectCard(
                            listing: listing,
                            favourite: isFav,
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                Routes.listing,
                                arguments: listing,
                              );
                            },
                            onFavourite: () {
                              state.toggleFavourite(listing.slug.isNotEmpty ? listing.slug : listing.id);
                            },
                          );
                        },
                      ),
                    ),

                  if (_isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xffea812e)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Pinned Bottom Bar: FigCta + AppTabBar
          Positioned(
            left: 0,
            right: 0,
            bottom: kTabBarStrip,
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
        ],
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xff2d3748),
            Color(0xff1a202c),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.apartment,
          size: 48,
          color: Color(0x40ffffff),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _getRoleName(kind, l10n),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

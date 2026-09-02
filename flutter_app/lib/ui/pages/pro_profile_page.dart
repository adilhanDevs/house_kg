// «Профиль продавца (Pro)» — точное визуальное соответствие эталону Reference 1 с динамической архитектурой Flutter.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../data/listing_repository.dart';
import '../../data/listings.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import '../auth_guard.dart';
import '../object_card.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_latest_notifications.dart';
import 'profile_page.dart' show LanguageToggleWidget;

const Color _danger = Color(0xffd93025);
const Color _accent = Color(0xffea812e);

class ProProfilePage extends StatefulWidget {
  const ProProfilePage({super.key});

  @override
  State<ProProfilePage> createState() => _ProProfilePageState();
}

class _ProProfilePageState extends State<ProProfilePage> {
  PropertyKind _selectedKind = PropertyKind.newBuilding;
  late final ListingRepository _repository;
  List<Listing> _listings = [];
  int? _activeCount;
  int? _soldCount;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final state = AppScope.read(context);
    _repository = ListingRepository(state.apiClient);
    if (state.isAuthenticated) {
      _loadListings();
      state.fetchProfile();
    } else {
      _isLoading = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppScope.read(context).pro = true;
      }
    });
  }

  Future<void> _loadListings() async {
    try {
      final mine = await _repository.getMyListings();
      if (mounted) {
        setState(() {
          _listings = mine.results;
          _activeCount = mine.count ?? mine.results.length;
          _isLoading = false;
        });
      }
      final sold = await _repository.getMyListings(status: 'sold');
      if (mounted) {
        setState(() => _soldCount = sold.count ?? sold.results.length);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<(PropertyKind, String)> _getCategoryTabs(AppLocalizations l10n) => [
        (PropertyKind.newBuilding, l10n.kindNewBuilding),
        (PropertyKind.apartment, l10n.kindApartment),
        (PropertyKind.commercial, l10n.kindCommercial),
      ];

  String _emptyMessageForKind(PropertyKind kind, AppLocalizations l10n) {
    return switch (kind) {
      PropertyKind.newBuilding => l10n.proEmptyNewBuildings,
      PropertyKind.apartment => l10n.proEmptyApartments,
      PropertyKind.commercial => l10n.proEmptyCommercial,
      PropertyKind.house => l10n.proEmptyHouses,
      PropertyKind.plot => l10n.proEmptyPlots,
      PropertyKind.room => l10n.proEmptyRooms,
    };
  }

  bool _isLoggingOut = false;

  Future<void> _confirmLogOut(BuildContext context) async {
    if (_isLoggingOut) return;
    final l10n = context.l10n;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        title: Text(l10n.profileLogoutConfirmTitle),
        content: Text(l10n.profileLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Выйти', style: TextStyle(color: _danger)),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;

    setState(() => _isLoggingOut = true);
    final state = AppScope.read(context);
    final navigator = Navigator.of(context);

    try {
      await state.logout();
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }

    if (mounted) {
      navigator.pushNamedAndRemoveUntil(Routes.welcome, (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      bottomNavigationBar: const AppTabBar(active: 4),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadListings();
          await AppScope.read(context).fetchProfile();
        },
        color: _accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Верхний Cover Header со скруглённым низом и перекрывающим аватаром (Reference 1)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ProfileCover(
                    url: state.userProfileCoverUrl,
                    width: double.infinity,
                    height: 245.0,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24.0),
                      bottomRight: Radius.circular(24.0),
                    ),
                    darken: true,
                  ),
                  Positioned(
                    left: 20.0,
                    bottom: -36.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(18.0),
                        border: Border.all(color: Colors.white, width: 3.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1a000000),
                            offset: Offset(0, 4),
                            blurRadius: 10.0,
                          ),
                        ],
                      ),
                      child: ProfileAvatar(
                        url: state.userAvatarUrl,
                        initials: state.userInitials,
                        size: 72.0,
                        radius: 15.0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 48.0),

              // 2. Блок имени, статистики и плашки роли (Reference 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            state.userName ?? l10n.profileNoName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.3,
                              color: Color(0xff000000),
                            ),
                          ),
                          const SizedBox(height: 5.0),
                          Text(
                            l10n.proObjectsCount(_activeCount ?? 0),
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: Color(0xff7d7d7d),
                            ),
                          ),
                          const SizedBox(height: 2.0),
                          Text(
                            l10n.proSold(_soldCount ?? 0),
                            style: const TextStyle(
                              fontSize: 14.0,
                              fontWeight: FontWeight.w400,
                              color: Color(0xff7d7d7d),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f1ff),
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text(
                        state.localizedRoleLabel(l10n),
                        style: const TextStyle(
                          fontSize: 14.0,
                          fontWeight: FontWeight.w600,
                          color: Color(0xff006cfb),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24.0),

              // 3. Табы категорий на всю доступную ширину (Reference 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    for (final (kind, label) in _getCategoryTabs(l10n))
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (_selectedKind != kind) {
                              setState(() => _selectedKind = kind);
                            }
                          },
                          child: Container(
                            height: 38.0,
                            margin: const EdgeInsets.symmetric(horizontal: 2.0),
                            decoration: BoxDecoration(
                              color: _selectedKind == kind
                                  ? const Color(0xfffbeee3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    fontWeight: _selectedKind == kind ? FontWeight.w600 : FontWeight.w500,
                                    color: _selectedKind == kind ? _accent : const Color(0xff8e8e93),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20.0),

              // 4. Большая карточка «Добавить объявление» на всю ширину (Reference 2)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!requireAuth(context, reason: l10n.adMustSelectCategory)) return;
                    Navigator.of(context).pushNamed(Routes.ad);
                  },
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 68.0),
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xffffffff),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(color: const Color(0xffe5e5ea), width: 1.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x06000000),
                          offset: Offset(0, 2),
                          blurRadius: 8.0,
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const _AddListingIcon(size: 34.0, color: _accent),
                        const SizedBox(width: 16.0),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.proAddListing,
                                style: const TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                  color: Color(0xff000000),
                                ),
                              ),
                              const SizedBox(height: 3.0),
                              const Text(
                                'Добавьте первый объект',
                                style: TextStyle(
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w400,
                                  color: Color(0xff7d7d7d),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24.0),

              // 5. Заголовок «Все объявления» и 2 крупные карточки в ряд (Reference 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Все объявление',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: Color(0xff000000),
                  ),
                ),
              ),
              const SizedBox(height: 14.0),

              SizedBox(
                height: 208.0,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accent))
                    : () {
                        final filtered = _listings.where((l) => l.kind == _selectedKind).toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Text(
                              _emptyMessageForKind(_selectedKind, l10n),
                              style: const TextStyle(
                                color: Color(0xff7d7d7d),
                                fontSize: 13.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14.0),
                          itemBuilder: (context, index) {
                            final l = filtered[index];
                            return ObjectCard(
                              listing: l,
                              favourite: state.isFavourite(l.id),
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.adPreview,
                                arguments: l.slug,
                              ),
                              onFavourite: () => state.toggleFavourite(l.id),
                            );
                          },
                        );
                      }(),
              ),
              const SizedBox(height: 24.0),

              // 6. Секция «Последние уведомления» (Reference 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: ProfileLatestNotifications(showTitle: true, maxItems: 1),
              ),
              const SizedBox(height: 24.0),

              // 7. Секция «Настройки» с просторным ритмом и тёплыми иконками (Reference 1)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Настройки',
                  style: TextStyle(
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                    color: Color(0xff000000),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _ProSettingRow(
                      icon: Icons.notifications_none,
                      label: l10n.profileNotificationsRow,
                      onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
                    ),
                    _ProSettingRow(
                      icon: Icons.person_outline,
                      label: l10n.profileAccountRow,
                      onTap: () => Navigator.of(context).pushNamed(Routes.account),
                    ),
                    _ProSettingRow(
                      icon: Icons.phone_in_talk_outlined,
                      label: l10n.profileSupportRow,
                      onTap: () => Navigator.of(context).pushNamed(Routes.support),
                    ),

                    // Строка переключателя языка
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11.0),
                      child: Row(
                        children: [
                          const Icon(Icons.language, size: 22.0, color: _accent),
                          const SizedBox(width: 14.0),
                          Expanded(
                            child: Text(
                              l10n.profileLanguageRow,
                              style: const TextStyle(
                                fontSize: 16.0,
                                fontWeight: FontWeight.w500,
                                color: Color(0xff000000),
                              ),
                            ),
                          ),
                          const LanguageToggleWidget(),
                        ],
                      ),
                    ),

                    // Кнопка выхода из аккаунта
                    if (state.isAuthenticated) ...[
                      const SizedBox(height: 6.0),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _isLoggingOut ? null : () => _confirmLogOut(context),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11.0),
                          child: Row(
                            children: [
                              Container(
                                width: 24.0,
                                height: 24.0,
                                decoration: BoxDecoration(
                                  color: const Color(0xfffde8e8),
                                  borderRadius: BorderRadius.circular(6.0),
                                ),
                                alignment: Alignment.center,
                                child: _isLoggingOut
                                    ? const SizedBox(
                                        width: 14.0,
                                        height: 14.0,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.0,
                                          color: _danger,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.logout,
                                        size: 16.0,
                                        color: _danger,
                                      ),
                              ),
                              const SizedBox(width: 12.0),
                              Expanded(
                                child: Text(
                                  _isLoggingOut ? l10n.profileLoggingOut : l10n.profileLogout,
                                  style: const TextStyle(
                                    fontSize: 15.0,
                                    fontWeight: FontWeight.w500,
                                    color: _danger,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                size: 20.0,
                                color: Color(0xffc7c7cc),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32.0),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProSettingRow extends StatelessWidget {
  const _ProSettingRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 22.0, color: _accent),
            const SizedBox(width: 14.0),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16.0,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff000000),
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 20.0,
              color: Color(0xffc7c7cc),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddListingIcon extends StatelessWidget {
  const _AddListingIcon({
    this.size = 34.0,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _AddListingIconPainter(color: color),
      ),
    );
  }
}

class _AddListingIconPainter extends CustomPainter {
  const _AddListingIconPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    const cornerLen = 8.0;
    const radius = 3.0;

    // Top-left corner
    final tl = Path()
      ..moveTo(0, cornerLen)
      ..lineTo(0, radius)
      ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
      ..lineTo(cornerLen, 0);
    canvas.drawPath(tl, paint);

    // Top-right corner
    final tr = Path()
      ..moveTo(w - cornerLen, 0)
      ..lineTo(w - radius, 0)
      ..arcToPoint(Offset(w, radius), radius: const Radius.circular(radius))
      ..lineTo(w, cornerLen);
    canvas.drawPath(tr, paint);

    // Bottom-left corner
    final bl = Path()
      ..moveTo(0, h - cornerLen)
      ..lineTo(0, h - radius)
      ..arcToPoint(Offset(radius, h), radius: const Radius.circular(radius))
      ..lineTo(cornerLen, h);
    canvas.drawPath(bl, paint);

    // Bottom-right corner
    final br = Path()
      ..moveTo(w - cornerLen, h)
      ..lineTo(w - radius, h)
      ..arcToPoint(Offset(w, h - radius), radius: const Radius.circular(radius))
      ..lineTo(w, h - cornerLen);
    canvas.drawPath(br, paint);

    // Center Plus
    final cx = w / 2;
    final cy = h / 2;
    const halfLen = 4.8;
    canvas.drawLine(Offset(cx - halfLen, cy), Offset(cx + halfLen, cy), paint);
    canvas.drawLine(Offset(cx, cy - halfLen), Offset(cx, cy + halfLen), paint);
  }

  @override
  bool shouldRepaint(covariant _AddListingIconPainter oldDelegate) => oldDelegate.color != color;
}

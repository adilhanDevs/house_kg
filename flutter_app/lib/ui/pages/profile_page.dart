// «Ваш профиль» — чистый вертикальный layout клиента с динамическими секциями.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../../l10n/l10n.dart';
import '../app_tab_bar.dart';
import '../auth_guard.dart';
import '../widgets/profile_identity.dart';
import '../widgets/profile_latest_notifications.dart';
import 'pro_profile_page.dart';

const Color _danger = Color(0xffd93025);
const Color _accent = Color(0xffea812e);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = AppScope.read(context);
        if (state.isAuthenticated) state.fetchProfile();
      }
    });
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

    if (state.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xffffffff),
        body: Center(
          child: CircularProgressIndicator(color: _accent),
        ),
      );
    }
    if (state.pro || state.isPro) {
      return const ProProfilePage();
    }

    return Scaffold(
      backgroundColor: const Color(0xfffefefe),
      bottomNavigationBar: const AppTabBar(active: 4),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await AppScope.read(context).fetchProfile();
          },
          color: _accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок экрана
                  const Text(
                    'Ваш профиль',
                    style: TextStyle(
                      fontSize: 22.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 20.0),

                  // Шапка пользователя: аватар, имя, телефон, плашка роли
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16.0),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0e000000),
                              offset: Offset(0, 2),
                              blurRadius: 8.0,
                            ),
                          ],
                        ),
                        child: ProfileAvatar(
                          url: state.userAvatarUrl,
                          initials: state.userInitials,
                          size: 68.0,
                          radius: 15.0,
                        ),
                      ),
                      const SizedBox(width: 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              (state.userName ?? '').isNotEmpty ? state.userName! : l10n.profileNoName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18.0,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                                letterSpacing: -0.2,
                                color: Color(0xff000000),
                              ),
                            ),
                            const SizedBox(height: 4.0),
                            Text(
                              state.userPhone ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.0,
                                fontWeight: FontWeight.w400,
                                height: 1.2,
                                color: Color(0xff7d7d7d),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: const Color(0xffe8f1ff),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          state.localizedRoleLabel(l10n),
                          style: const TextStyle(
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                            color: Color(0xff006cfb),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24.0),

                  // Секция «Последние уведомления»
                  const ProfileLatestNotifications(showTitle: true),
                  const SizedBox(height: 24.0),

                  // Секция «Настройки»
                  const Text(
                    'Настройки',
                    style: TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                      color: Color(0xff000000),
                    ),
                  ),
                  const SizedBox(height: 10.0),

                  _ProfileSettingRow(
                    icon: Icons.favorite_border,
                    label: l10n.profileFavoritesRow,
                    onTap: () => Navigator.of(context).pushNamed(Routes.favourites),
                  ),
                  _ProfileSettingRow(
                    icon: Icons.notifications_none,
                    label: l10n.profileNotificationsRow,
                    onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
                  ),
                  _ProfileSettingRow(
                    icon: Icons.person_outline,
                    label: l10n.profileAccountRow,
                    onTap: () => Navigator.of(context).pushNamed(Routes.account),
                  ),
                  _ProfileSettingRow(
                    icon: Icons.phone_in_talk_outlined,
                    label: l10n.profileSupportRow,
                    onTap: () => Navigator.of(context).pushNamed(Routes.support),
                  ),

                  // Строка переключателя языка
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
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
                    const SizedBox(height: 4.0),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _isLoggingOut ? null : () => _confirmLogOut(context),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
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

                  const SizedBox(height: 24.0),

                  // Кнопка «Продать недвижимость»
                  SizedBox(
                    width: double.infinity,
                    height: 48.0,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!requireAuth(context, reason: l10n.adMustSelectCategory)) return;
                        Navigator.of(context).pushNamed(Routes.ad);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        l10n.profileSellButton,
                        style: const TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20.0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingRow extends StatelessWidget {
  const _ProfileSettingRow({
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
        padding: const EdgeInsets.symmetric(vertical: 11.0),
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

class LanguageToggleWidget extends StatelessWidget {
  const LanguageToggleWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final isKy = state.languageCode == 'ky';

    return Container(
      width: 170.0,
      height: 32.0,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xffe3e3e8),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => AppScope.read(context).setLanguageCode('ru'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: !isKy ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  isKy ? 'Орусча' : 'Русский',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: !isKy ? FontWeight.w600 : FontWeight.w500,
                    color: !isKy ? Colors.white : const Color(0xff7d7d7d),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => AppScope.read(context).setLanguageCode('ky'),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: isKy ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Кыргызча',
                  style: TextStyle(
                    fontSize: 12.0,
                    fontWeight: isKy ? FontWeight.w600 : FontWeight.w500,
                    color: isKy ? Colors.white : const Color(0xff7d7d7d),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

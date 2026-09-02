// «Ваш профиль» — кадр 15 макета с работающими строками настроек и выходом.
//
// Кнопки «Выйти из аккаунта» в макете нет: она встаёт в пустое место между
// «Настройками» и «Продать недвижимость» и повторяет размер и радиус соседней
// кнопки, только контуром и красным — как принято у необратимых действий.
import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/routes.dart';
import '../auth_guard.dart';
import '../../app/stage.dart';
import '../../fig/fig.dart';
import '../app_tab_bar.dart';
import '../widgets/latest_notifications.dart';
import '../widgets/profile_identity.dart';
import 'pro_profile_page.dart';

/// Строки «Настроек» — в кадре они одинаковой высоты и идут через 44 pt.
const double _rowLeft = 23;
const double _rowWidth = 327;
const double _rowHeight = 26;

/// «Посмотреть все» под последними уведомлениями.
// Полоса нарисованных карточек уведомлений и ссылка «Посмотреть все» —
// координаты сняты измерением кадра, а не подобраны.
// Ширина 338, а не 326: нарисованный текст «Цена снизилась» уходит
// вправо до 362, и более узкая панель оставляла бы его край видимым.
const Rect _latestNotifications = Rect.fromLTWH(24, 215, 338, 143);
const Rect _seeAll = Rect.fromLTWH(24, 360, 326, 20);

/// «Продать недвижимость».
const Rect _sell = Rect.fromLTWH(101, 698, 185.3, 30);

/// «Выйти из аккаунта» — своя кнопка на месте, которое макет оставил пустым.
const Rect _logOut = Rect.fromLTWH(101, 652, 185.3, 30);

const Color _danger = Color(0xffd93025);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    // Имя, телефон и аватар в шапке — всегда свежие с сервера.
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
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xffffffff),
        surfaceTintColor: Colors.transparent,
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Избранное и фильтры этого сеанса будут забыты.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
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
    if (state.isInitializing) {
      return const Scaffold(
        backgroundColor: Color(0xffffffff),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xffea812e)),
        ),
      );
    }
    if (state.pro || state.isPro) {
      return const ProProfilePage();
    }
    return RefreshIndicator(
      onRefresh: () async {
        await AppScope.read(context).fetchProfile();
      },
      color: const Color(0xffea812e),
      child: FigStage(
      frame: frame('15'),
      bottomBar: const AppTabBar(active: 4),
      overlays: [
        // ——— Настоящая шапка профиля вместо статичной из макета ———
        Positioned(
          left: 24.0,
          top: 85.0,
          child: ProfileAvatar(
            url: state.userAvatarUrl,
            initials: state.userInitials,
            size: 64.0,
            radius: 12.0,
          ),
        ),

        // Маска поверх имени, телефона и плашки роли из кадра.
        const Positioned(
          left: 94.0,
          top: 96.0,
          width: 256.0,
          height: 44.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        Positioned(
          left: 96.0,
          top: 100.0,
          width: 180.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                (state.userName ?? '').isNotEmpty ? state.userName! : 'Без имени',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                  letterSpacing: -0.17,
                  color: Color(0xff000000),
                ),
              ),
              const SizedBox(height: 3.0),
              Text(
                state.userPhone ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.0,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                  color: Color(0xff7d7d7d),
                ),
              ),
            ],
          ),
        ),

        Positioned(
          left: 282.0,
          top: 104.0,
          child: RoleBadge(label: state.roleLabel),
        ),

        FigZone(
          _seeAll.left, _seeAll.top, _seeAll.width, _seeAll.height,
          label: 'Посмотреть все уведомления',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        // Настоящие уведомления поверх нарисованных карточек кадра.
        Positioned(
          left: _latestNotifications.left,
          top: _latestNotifications.top,
          width: _latestNotifications.width,
          height: _latestNotifications.height,
          child: LatestNotifications(
            width: _latestNotifications.width,
            height: _latestNotifications.height,
          ),
        ),
        FigZone(
          _rowLeft, 381, _rowWidth, _rowHeight,
          label: 'Вам понравилось',
          onTap: () => Navigator.of(context).pushNamed(Routes.favourites),
        ),
        FigZone(
          _rowLeft, 425, _rowWidth, _rowHeight,
          label: 'Тарифы',
          onTap: () => Navigator.of(context).pushNamed(Routes.tariffs),
        ),
        FigZone(
          _rowLeft, 469, _rowWidth, _rowHeight,
          label: 'Уведомление',
          onTap: () => Navigator.of(context).pushNamed(Routes.notifications),
        ),
        FigZone(
          _rowLeft, 513, _rowWidth, _rowHeight,
          label: 'Аккаунт',
          onTap: () => Navigator.of(context).pushNamed(Routes.account),
        ),
        FigZone(
          _rowLeft, 557, _rowWidth, _rowHeight,
          label: 'Служба поддержки',
          onTap: () => Navigator.of(context).pushNamed(Routes.support),
        ),

        // Маска для закрашивания статичной плашки макета и линии (Y=594)
        const Positioned(
          left: 150.0,
          top: 594.0,
          width: 225.0,
          height: 48.0,
          child: ColoredBox(color: Color(0xffffffff)),
        ),

        // Полноценная пересверстанная кнопка-переключатель языка (Y=605)
        const Positioned(
          left: 175.0,
          top: 605.0,
          child: LanguageToggleWidget(),
        ),
        // Клик по кнопке макета «Продать недвижимость» (Y=696)
        FigZone(
          101.0, 696.0, 185.3, 30.0,
          label: 'Продать недвижимость',
          onTap: () {
            if (!requireAuth(context, reason: 'Войдите, чтобы разместить объявление')) return;
            Navigator.of(context).pushNamed(Routes.ad);
          },
        ),

        // На месте «Служба безопасности» (Y=645) размещаем «Выйти из аккаунта»
        if (state.isAuthenticated)
          Positioned(
            left: _rowLeft,
            top: 645.0,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isLoggingOut ? null : () => _confirmLogOut(context),
              child: Container(
                width: _rowWidth,
                height: 40.0,
                color: const Color(0xffffffff),
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
                    Text(
                      _isLoggingOut ? 'Выход...' : 'Выйти из аккаунта',
                      style: const TextStyle(
                        fontSize: 15.0,
                        fontWeight: FontWeight.w500,
                        color: _danger,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 14.0,
                      color: Color(0xffc7c7cc),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
    );
  }
}

class LanguageToggleWidget extends StatefulWidget {
  final String initialLang;
  final ValueChanged<String>? onChanged;

  const LanguageToggleWidget({
    super.key,
    this.initialLang = 'ru',
    this.onChanged,
  });

  @override
  State<LanguageToggleWidget> createState() => _LanguageToggleWidgetState();
}

class _LanguageToggleWidgetState extends State<LanguageToggleWidget> {
  late String _selectedLang;

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.initialLang;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170.0,
      height: 28.0,
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        color: const Color(0xffe3e3e8),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedLang = 'ru');
                widget.onChanged?.call('ru');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedLang == 'ru' ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Русский',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _selectedLang == 'ru' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedLang == 'ru' ? Colors.white : const Color(0xff7d7d7d),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                setState(() => _selectedLang = 'kg');
                widget.onChanged?.call('kg');
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: _selectedLang == 'kg' ? const Color(0xff78787c) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Кыргызский',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _selectedLang == 'kg' ? FontWeight.bold : FontWeight.w500,
                    color: _selectedLang == 'kg' ? Colors.white : const Color(0xff7d7d7d),
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

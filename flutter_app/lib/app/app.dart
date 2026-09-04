// Приложение поверх кадров макета: состояние над навигатором, маршруты по
// таблице [kFrameRoute].
//
// Готовы не все страницы — те маршруты, до которых ещё не дошли руки,
// открывают соответствующий кадр макета как картинку (с кнопкой «назад»),
// чтобы приложение оставалось проходимым.
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../push/push_coordinator.dart';

import 'route_observer.dart';
import '../ui/app_tab_bar.dart';
import '../ui/fig_cta.dart';
import '../ui/pages/account_page.dart';
import '../ui/pages/ad_edit_page.dart';
import '../ui/pages/ad_form_page.dart';
import '../ui/pages/ad_photos_page.dart';
import '../ui/pages/ad_preview_page.dart';
import '../ui/pages/ad_promo_page.dart';
import '../ui/pages/ad_video_page.dart';
import '../ui/pages/agent_listings_page.dart';
import '../ui/pages/catalog_page.dart';
import '../ui/pages/category_page.dart';
import '../ui/pages/code_page.dart';
import '../ui/pages/favourites_page.dart';
import '../ui/pages/filter_page.dart';
import '../ui/pages/home_page.dart';
import '../ui/pages/listing_page.dart';
import '../ui/pages/notifications_page.dart';
import '../ui/pages/onboarding_page.dart';
import '../ui/pages/photos_page.dart';
import '../ui/pages/pro_photo_confirm_page.dart';
import '../ui/pages/pro_profile_page.dart';
import '../ui/pages/pro_signup_page.dart';
import '../ui/pages/profile_page.dart';
import '../ui/pages/splash_page.dart';
import '../ui/pages/support_page.dart';
import '../ui/pages/tariffs_page.dart';
import '../ui/pages/topup_page.dart';
import '../ui/pages/view_history_page.dart';
import '../ui/pages/video_page.dart';
import '../ui/pages/wallet_history_page.dart';
import '../data/code_flow.dart';
import '../ui/pages/chat_page.dart';
import '../ui/pages/conversations_page.dart';
import '../ui/pages/password_reset_page.dart';
import '../ui/pages/register_page.dart';
import '../ui/pages/welcome_page.dart';
import '../data/ad_media.dart';
import '../data/api_client.dart';
import '../data/listings.dart';
import '../l10n/l10n.dart';
import 'app_state.dart';
import 'routes.dart';
import 'stage.dart';

class HouseKgzAppScope extends StatefulWidget {
  const HouseKgzAppScope({
    super.key,
    this.initialRoute = Routes.splash,
    this.media = const DeviceMedia(),
    this.apiClient,
    this.pushMessaging,
  });

  final String initialRoute;

  /// Откуда объявление берёт снимки и ролики. По умолчанию — галерея и камера
  /// устройства; в тестах на это место встаёт заглушка.
  final MediaSource media;

  final ListingApiClient? apiClient;
  final PushMessaging? pushMessaging;

  @override
  State<HouseKgzAppScope> createState() => _HouseKgzAppScopeState();
}

class _HouseKgzAppScopeState extends State<HouseKgzAppScope> with WidgetsBindingObserver {
  late final AppState _state = AppState(
    media: widget.media,
    apiClient: widget.apiClient,
  );

  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _pushRoutes = _PushRouteObserver(_schedulePushNavigation);
  PushCoordinator? _push;
  bool _pushLoggingOut = false;
  bool _pushResuming = false;
  Future<String>? _deviceId;

  Future<String> _installationId() => _deviceId ??= () async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString('push_installation_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString('push_installation_id', id);
    return id;
  }();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final messaging = widget.pushMessaging;
    if (messaging != null) {
      _push = PushCoordinator(
        messaging: messaging,
        register: (token) async => _state.apiClient.registerPushDevice(
          token: token, deviceId: await _installationId(), locale: _state.languageCode),
        deactivate: () async => _state.apiClient.deactivatePushDevice(await _installationId()),
        onForeground: _state.refreshPushNotifications,
        onPending: _schedulePushNavigation,
      );
      _state.beforeLogout = () async {
        _pushLoggingOut = true;
        await _push!.logout();
      };
      _state.addListener(_syncPushSession);
      unawaited(_push!.start());
      _syncPushSession();
    }
  }

  void _syncPushSession() {
    if (_state.isInitializing) return;
    if (!_state.isAuthenticated) _pushLoggingOut = false;
    if (_pushLoggingOut) return;
    unawaited(_push?.setUser(_state.isAuthenticated ? _state.userId : null));
    _schedulePushNavigation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_pushLoggingOut) {
      unawaited(_resumePush());
    }
  }

  Future<void> _resumePush() async {
    if (_push == null || _pushResuming) return;
    _pushResuming = true;
    try {
      if (_state.isAuthenticated && _state.userId == null && !_state.isInitializing) {
        await _state.fetchProfile();
      }
      if (!mounted || _pushLoggingOut) return;
      _syncPushSession();
      await _push?.resume();
      if (mounted) _schedulePushNavigation();
    } finally {
      _pushResuming = false;
    }
  }

  void _schedulePushNavigation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pushLoggingOut || _state.isInitializing || !_state.isAuthenticated) return;
      final navigator = _navigatorKey.currentState;
      final intent = _push?.takePending(navigationReady: navigator != null && _pushRoutes.ready);
      if (intent == null || navigator == null) return;
      navigator.pushNamed(
        intent.type == 'new_message' ? Routes.conversation : Routes.listing,
        arguments: intent.conversationId ?? intent.listingSlug,
      );
      final notificationId = int.tryParse(intent.notificationId ?? '');
      if (notificationId != null) {
        unawaited(_state.markNotificationRead(notificationId));
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.removeListener(_syncPushSession);
    _state.beforeLogout = null;
    unawaited(_push?.dispose());
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: ListenableBuilder(
        listenable: _state,
        builder: (context, _) => MaterialApp(
          navigatorKey: _navigatorKey,
          title: 'House KGZ',
          debugShowCheckedModeBanner: false,
          locale: _state.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: FigColors.page,
            dialogBackgroundColor: const Color(0xffffffff),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xffffffff),
              surfaceTintColor: Colors.transparent,
            ),
            bottomSheetTheme: const BottomSheetThemeData(
              backgroundColor: Color(0xffffffff),
              surfaceTintColor: Colors.transparent,
            ),
            colorScheme: ColorScheme.fromSeed(
              seedColor: FigColors.accent,
              surface: const Color(0xffffffff),
              surfaceContainer: const Color(0xffffffff),
              surfaceContainerHigh: const Color(0xffffffff),
              surfaceContainerHighest: const Color(0xffffffff),
              surfaceContainerLow: const Color(0xffffffff),
              surfaceContainerLowest: const Color(0xffffffff),
            ),
          ),
          initialRoute: widget.initialRoute,
          onGenerateInitialRoutes: (String initialRouteName) {
            final uri = Uri.tryParse(initialRouteName);
            final path = uri != null && uri.path.isNotEmpty ? uri.path : initialRouteName;
            if (path == Routes.splash || path == '/') {
              return [_route(const RouteSettings(name: Routes.splash))];
            }
            return [_route(RouteSettings(name: path, arguments: uri?.queryParameters))];
          },
          onGenerateRoute: _route,
          navigatorObservers: [appRouteObserver, _pushRoutes],
        ),
      ),
    );
  }

  Route<dynamic> _route(RouteSettings settings) {
    final name = settings.name ?? Routes.catalog;
    final rawArgs = settings.arguments;
    final id = (rawArgs is ListingArgs)
        ? rawArgs.id
        : ((rawArgs is String && rawArgs.isNotEmpty) ? rawArgs : '');
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => switch (name) {
        Routes.splash => const SplashPage(),
        Routes.welcome => const FramePage(route: Routes.welcome),
        Routes.register => const RegisterPage(),
        Routes.passwordReset => const PasswordResetPage(),
        Routes.onboarding => const OnboardingPage(),
        // Экран кода принимает либо номер (вход), либо заполненную форму
        // регистрации — жёсткий каст на String ронял второй случай.
        Routes.code => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final flow = args is CodeFlow ? args : null;
                return CodePage(
                  phone: args is String ? args : null,
                  flow: flow,
                  resendAfter: flow?.resendAfter ?? 60,
                );
              },
            ),
        Routes.proSignup => const FramePage(route: Routes.proSignup),
        Routes.proCode => const FramePage(route: Routes.proCode),
        Routes.proPhoto1 => const FramePage(route: Routes.proPhoto1),
        Routes.proPhoto2 => const FramePage(route: Routes.proPhoto2),
        Routes.topup => const TopUpPage(),
        Routes.history => const WalletHistoryPage(),
        Routes.home => const HomePage(),
        Routes.catalog => const CatalogPage(),
        Routes.favourites => const FavouritesPage(),
        Routes.notifications => const NotificationsPage(),
        Routes.conversations => const ConversationsPage(),
        Routes.conversation => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is ChatArgs) return ChatPage(args: args);
                // Из уведомления может прийти только идентификатор строкой.
                if (args is String && args.isNotEmpty) {
                  return ChatPage(args: ChatArgs(args));
                }
                return const ConversationsPage();
              },
            ),
        Routes.viewHistory => const ViewHistoryPage(),
        Routes.profile || Routes.pro => Builder(
              builder: (context) {
                final state = AppScope.of(context);
                if (state.isInitializing) {
                  return const Scaffold(
                    backgroundColor: Color(0xffffffff),
                    body: Center(
                      child: CircularProgressIndicator(color: Color(0xffea812e)),
                    ),
                  );
                }
                return (state.pro || state.isPro)
                    ? const ProProfilePage()
                    : const ProfilePage();
              },
            ),
        Routes.account => const AccountPage(),
        Routes.support => const SupportPage(),
        Routes.filter => const FilterPage(),
        Routes.category => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final kind = args is CategoryPageArgs ? args.kind : PropertyKind.newBuilding;
                return CategoryPage(kind: kind);
              },
            ),
        Routes.listing => ListingPage(id: id),
        Routes.listingPhotos => PhotosPage(id: id),
        Routes.listingVideo => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                final initialIdx = (args is ListingArgs) ? args.initialVideoIndex : 0;
                return VideoPage(id: id, initialVideoIndex: initialIdx);
              },
            ),
        Routes.ad => const AdFormPage(),
        Routes.adForm => Builder(
              builder: (context) {
                final slug = ModalRoute.of(context)?.settings.arguments as String?;
                return AdFormPage(slug: slug);
              },
            ),
        Routes.adEdit => Builder(
              builder: (context) {
                final slug = ModalRoute.of(context)?.settings.arguments as String?;
                return AdEditPage(slug: slug, media: widget.media);
              },
            ),
        Routes.adPhotos => const AdPhotosPage(),
        Routes.adVideo => const AdVideoPage(),
        Routes.adPromo => const AdPromoPage(),
        Routes.adPreview => Builder(
              builder: (context) {
                final slug = ModalRoute.of(context)?.settings.arguments as String?;
                return AdPreviewPage(slug: slug);
              },
            ),
        Routes.tariffs || Routes.subscriptions => const TariffsPage(),
        Routes.agentListings || Routes.agent || Routes.agentProfile => Builder(
              builder: (context) {
                final args = ModalRoute.of(context)?.settings.arguments;
                if (args is AgentListingsArgs) {
                  return AgentListingsPage(args: args);
                }
                if (args is int) {
                  return AgentListingsPage(args: AgentListingsArgs(sellerId: args));
                }
                if (args is String && args.isNotEmpty) {
                  final parsedId = int.tryParse(args);
                  if (parsedId != null) {
                    return AgentListingsPage(args: AgentListingsArgs(sellerId: parsedId));
                  }
                }
                return const AgentListingsPage();
              },
            ),
        _ => FramePage(route: name),
      },
    );
  }
}

/// Кадр макета как заглушка для маршрута, у которого ещё нет своей страницы.
class FramePage extends StatelessWidget {
  const FramePage({super.key, required this.route});

  final String route;

  @override
  Widget build(BuildContext context) {
    if (route == Routes.welcome) {
      return const WelcomePage();
    }
    if (route == Routes.proSignup) {
      return const ProSignupPage();
    }
    if (route == Routes.proCode) {
      final args = ModalRoute.of(context)?.settings.arguments;
      final flow = args is CodeFlow ? args : null;
      return CodePage(
        nextRoute: Routes.proPhoto1,
        phone: args is String ? args : null,
        flow: flow,
        resendAfter: flow?.resendAfter ?? 60,
      );
    }
    if (route == Routes.proPhoto1 || route == Routes.proPhoto2) {
      return const ProPhotoConfirmPage();
    }
    final number = frameNumberForRoute(route);
    if (number == null) {
      return Scaffold(
        body: Center(child: Text('Нет кадра для $route')),
      );
    }
    final figScreen = frame(number);
    final tab = route == Routes.pro ? 4 : kTabRoutes.indexOf(route);

    // Нижнее меню есть не только на вкладках: макет рисует его и на страницах,
    // куда приходят из списка, — «Объекты продавца», «Мои фильтры», «Подборка».
    // Сам кадр меню не рисует, его место в кадре помечено [FigScreen.tabBarAt],
    // поэтому меню приложения приходится ставить сюда. Подсветку берём у
    // кадра: там отмечена вкладка, с которой на экран приходят.
    final hasTabBar = tab >= 0 || figScreen.hasTabBar;
    final activeTab = tab >= 0 ? tab : figScreen.activeTab;

    // Низ экрана держит приложение, а не кадр: под чертой макет рисует полосу
    // меню и обрезок следующего ряда карточек — вместо них встаёт живое меню.
    // Кнопка же ложится поверх кадра, ровно на ту, что он нарисовал: карточки
    // за ней видно, как в макете.
    final cta = figScreen.pinnedCta;
    final cutBelow = figScreen.tabBarAt?.dy;
    const bottomHeight = kTabBarHeight;

    final hotspotOverlays = <Widget>[];
    for (final hotspot in figScreen.hotspots) {
      hotspotOverlays.add(
        FigZone(
          hotspot.left,
          hotspot.top,
          hotspot.width,
          hotspot.height,
          label: hotspot.label,
          onTap: () {
            final state = AppScope.read(context);
            if (hotspot.pro != null) {
              state.pro = hotspot.pro!;
            }
            if (hotspot.back) {
              if (Navigator.canPop(context)) {
                Navigator.of(context).pop();
              } else {
                Navigator.of(context).pushReplacementNamed(Routes.home);
              }
            } else {
              final targetRoute = routeForTarget(hotspot.target);
              if (targetRoute != null) {
                Navigator.of(context).pushNamed(targetRoute);
              }
            }
          },
        ),
      );
    }

    VoidCallback? onTapAnywhere;
    if (figScreen.tapAnywhereTo != null) {
      onTapAnywhere = () {
        final targetRoute = routeForTarget(figScreen.tapAnywhereTo!);
        if (targetRoute != null) {
          Navigator.of(context).pushNamed(targetRoute);
        }
      };
    }

    return FigStage(
      frame: figScreen,
      cutBelow: hasTabBar || cta != null ? cutBelow : null,
      bottomBarHeight: bottomHeight,
      bottomBar: !hasTabBar && cta == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (cta != null) FigCta(label: cta.label),
                if (hasTabBar) AppTabBar(active: activeTab),
              ],
            ),
      onTapAnywhere: onTapAnywhere,
      overlays: [
        if (tab < 0 && route != Routes.topup && route != Routes.code && route != Routes.proCode && Navigator.of(context).canPop()) const FigBackButton(),
        ...hotspotOverlays,
      ],
    );
  }
}

/// Splash/login transitions finish before a queued push can enter the stack.
class _PushRouteObserver extends NavigatorObserver {
  _PushRouteObserver(this.changed);
  final VoidCallback changed;
  bool ready = false;
  void _update(Route<dynamic>? route) {
    ready = route != null && !{
      Routes.splash, Routes.onboarding, Routes.welcome, Routes.register,
      Routes.code, Routes.proCode, Routes.proSignup, Routes.passwordReset,
    }.contains(route.settings.name);
    changed();
  }
  @override void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(route);
  @override void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _update(newRoute);
  @override void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _update(previousRoute);
}

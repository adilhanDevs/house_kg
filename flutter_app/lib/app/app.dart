// Приложение поверх кадров макета: состояние над навигатором, маршруты по
// таблице [kFrameRoute].
//
// Готовы не все страницы — те маршруты, до которых ещё не дошли руки,
// открывают соответствующий кадр макета как картинку (с кнопкой «назад»),
// чтобы приложение оставалось проходимым.
import 'dart:async';
import 'package:flutter/material.dart';

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
import '../ui/pages/password_reset_page.dart';
import '../ui/pages/register_page.dart';
import '../ui/pages/welcome_page.dart';
import '../data/ad_media.dart';
import '../data/api_client.dart';
import '../data/listings.dart';
import 'app_state.dart';
import 'routes.dart';
import 'stage.dart';

class HouseKgzAppScope extends StatefulWidget {
  const HouseKgzAppScope({
    super.key,
    this.initialRoute = Routes.splash,
    this.media = const DeviceMedia(),
    this.apiClient,
  });

  final String initialRoute;

  /// Откуда объявление берёт снимки и ролики. По умолчанию — галерея и камера
  /// устройства; в тестах на это место встаёт заглушка.
  final MediaSource media;

  final ListingApiClient? apiClient;

  @override
  State<HouseKgzAppScope> createState() => _HouseKgzAppScopeState();
}

class _HouseKgzAppScopeState extends State<HouseKgzAppScope> {
  late final AppState _state = AppState(
    media: widget.media,
    apiClient: widget.apiClient,
  );

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: _state,
      child: MaterialApp(
        title: 'House KGZ',
        debugShowCheckedModeBanner: false,
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
        onGenerateRoute: _route,
        navigatorObservers: [appRouteObserver],
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

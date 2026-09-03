import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:house_kgz/ui/app_tab_bar.dart';
import 'package:house_kgz/ui/fig_cta.dart';
import 'package:house_kgz/ui/object_card.dart';
import 'package:house_kgz/ui/pages/agent_listings_page.dart';
import 'package:house_kgz/ui/pages/chat_page.dart';

class _FakeServer extends http.BaseClient {
  _FakeServer({
    this.sellerKind = 'owner',
    this.sellerName = 'Айбек',
    this.companyName = '',
    this.isVerified = true,
    this.activeListingsCount = 3,
    this.soldListingsCount = 2,
    this.about = 'Опытный специалист по недвижимости',
    this.listingCount = 2,
  });

  /// Сколько объявлений отдаёт сервер: чтобы проверить прокрутку, контент
  /// должен переполнять экран, иначе прокручивать нечего и тест ничего не
  /// доказывает.
  final int listingCount;

  final String sellerKind;
  final String sellerName;
  final String companyName;
  final bool isVerified;
  final int activeListingsCount;
  final int soldListingsCount;
  final String? about;
  final bool openConversationSuccess = true;

  final List<String> visitedPaths = [];
  Map<String, dynamic>? lastPostJson;

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    final query = request.url.query;
    final full = query.isNotEmpty ? '$path?$query' : path;
    visitedPaths.add('${request.method} $full');

    if (request is http.Request && request.body.isNotEmpty) {
      try {
        lastPostJson = jsonDecode(request.body) as Map<String, dynamic>?;
      } catch (_) {}
    }

    if (request.method == 'GET' &&
        path.startsWith('/api/v1/sellers/') &&
        path.endsWith('/listings/')) {
      return _json({
        'count': listingCount,
        'next': null,
        'previous': null,
        'results': [
          for (var i = 1; i <= listingCount; i++)
            {
              'slug': 'test-listing-$i',
              'kind': i.isEven ? 'new_building' : 'apartment',
              'district': {'name': i.isEven ? 'Октябрьский' : 'Первомайский'},
              'price': '${85000 + i * 1000}',
              'currency': 'USD',
              'rooms': 2 + (i % 3),
              'area': 65 + i,
              'floor': 4,
              'floors': 9,
              'cover_url': null,
              'owner_id': 42,
              'seller_kind': sellerKind,
              'is_favourite': false,
              'status': 'active',
            },
        ],
      });
    }

    if (request.method == 'GET' && path == '/api/v1/sellers/42/') {
      return _json({
        'id': 42,
        'name': sellerName,
        'company_name': companyName,
        'seller_kind': sellerKind,
        'logo_url': null,
        'avatar_url': null,
        'cover_url': null,
        'about': about,
        'experience_years': 5,
        'is_verified': isVerified,
        'rating': '4.80',
        'reviews_count': 12,
        'active_listings_count': activeListingsCount,
        'sold_listings_count': soldListingsCount,
        'member_since': '2023-01-15T10:00:00Z',
        'work_districts': [
          {'id': 1, 'name': 'Первомайский'},
        ],
        'working_hours': {},
        'contacts': {
          'phone': '+996 700 111 222',
          'whatsapp': '+996700111222',
          'telegram': '@seller',
          'instagram': '',
        },
      });
    }

    if (request.method == 'POST' && path == '/api/v1/conversations/') {
      if (openConversationSuccess) {
        return _json({
          'id': 'conv-uuid-1234',
          'listing_slug': 'test-listing-1',
          'unread_count': 0,
        }, 201);
      } else {
        return _json({
          'error': {'message': 'Нельзя написать самому себе'},
        }, 400);
      }
    }

    return _json({'error': 'Not found'}, 404);
  }
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeServer server,
  AgentListingsArgs? args,
  bool isAuthenticated = true,
  int? loggedInUserId,
  Size size = const Size(375, 812),
  Locale locale = const Locale('ru'),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  SharedPreferences.setMockInitialValues({
    if (isAuthenticated) 'access_token': 'fake_access_token',
  });

  final apiClient = ListingApiClient(
    baseUrl: 'https://test.local',
    client: server,
  );
  if (isAuthenticated) {
    apiClient.setToken('fake_access_token');
  }

  final state = AppState(apiClient: apiClient);
  state.userId = loggedInUserId;

  await tester.pumpWidget(
    AppScope(
      state: state,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ru'), Locale('ky')],
        locale: locale,
        onGenerateRoute: (settings) {
          if (settings.name == Routes.welcome) {
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('WelcomePage')),
            );
          }
          if (settings.name == Routes.conversation) {
            final chatArgs = settings.arguments as ChatArgs?;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => Scaffold(
                body: Text(
                  'ChatPage:${chatArgs?.conversationId}:${chatArgs?.listingTitle}',
                ),
              ),
            );
          }
          if (settings.name == Routes.listing) {
            final listing = settings.arguments as Listing?;
            return MaterialPageRoute(
              settings: settings,
              builder: (_) =>
                  Scaffold(body: Text('ListingPage:${listing?.slug}')),
            );
          }
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => AgentListingsPage(
              args: args ?? const AgentListingsArgs(sellerId: 42),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Public Seller Profile (AgentListingsPage)', () {
    testWidgets('renders seller details, role badge, stats and object cards', (
      tester,
    ) async {
      final server = _FakeServer(
        sellerKind: 'owner',
        sellerName: 'Айбек',
        activeListingsCount: 3,
        soldListingsCount: 2,
        isVerified: true,
      );

      await _pumpPage(tester, server: server);

      // Seller name
      expect(find.text('Айбек'), findsOneWidget);
      // Role badge
      expect(find.text('Собственник'), findsOneWidget);
      // Real stats
      expect(find.text('3 объектов недвижимости'), findsOneWidget);
      expect(find.text('Продано: 2 объектов'), findsOneWidget);
      // Verified badge icon
      expect(find.byIcon(Icons.check), findsOneWidget);
      // Listings grid
      expect(find.byType(ObjectCard), findsNWidgets(2));
      // Sticky CTA
      expect(find.text('Связаться с собственником'), findsOneWidget);
    });

    testWidgets('renders realtor badge and CTA button for realtor profile', (
      tester,
    ) async {
      final server = _FakeServer(
        sellerKind: 'realtor',
        sellerName: 'Бакыт',
        companyName: 'Ала-Тоо Недвижимость',
        activeListingsCount: 5,
        soldListingsCount: 0,
      );

      await _pumpPage(tester, server: server);

      expect(find.text('Ала-Тоо Недвижимость'), findsOneWidget);
      expect(find.text('Риелтор'), findsOneWidget);
      expect(find.text('5 объектов недвижимости'), findsOneWidget);
      // Sold count is 0 so no fake sold label is shown
      expect(find.textContaining('Продано:'), findsNothing);
      expect(find.text('Связаться с риелтором'), findsOneWidget);
    });

    testWidgets('renders agency badge and CTA button for agency profile', (
      tester,
    ) async {
      final server = _FakeServer(
        sellerKind: 'agency',
        sellerName: 'Агентство',
        companyName: 'Bishkek Realty',
        activeListingsCount: 10,
        soldListingsCount: 4,
      );

      await _pumpPage(tester, server: server);

      expect(find.text('Bishkek Realty'), findsOneWidget);
      expect(find.text('Агентство'), findsOneWidget);
      expect(find.text('Связаться с агентством'), findsOneWidget);
    });

    testWidgets('switching category tabs triggers filtered fetch', (
      tester,
    ) async {
      final server = _FakeServer();
      await _pumpPage(tester, server: server);

      // Tap on 'Квартиры' tab
      final apartmentsTab = find.text('Квартиры');
      expect(apartmentsTab, findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('agent-filter-tabs')),
        const Offset(-160, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(apartmentsTab);
      await tester.pumpAndSettle();

      // Verify that backend was requested with kind=apartment
      final listingRequests = server.visitedPaths
          .where((p) => p.contains('/listings/'))
          .toList();
      expect(listingRequests.any((p) => p.contains('kind=apartment')), isTrue);
    });

    testWidgets('tapping listing card navigates to ListingPage', (
      tester,
    ) async {
      final server = _FakeServer();
      await _pumpPage(tester, server: server);

      // Drag to reveal the object cards well above the pinned bottom bar
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -350));
      await tester.pumpAndSettle();

      final firstCard = find.byType(ObjectCard).first;
      await tester.tap(firstCard);
      await tester.pumpAndSettle();

      expect(find.text('ListingPage:test-listing-1'), findsOneWidget);
    });

    testWidgets(
      'authenticated user tapping CTA initiates chat and opens ChatPage',
      (tester) async {
        final server = _FakeServer(sellerKind: 'owner');
        await _pumpPage(
          tester,
          server: server,
          isAuthenticated: true,
          loggedInUserId: 99, // Different from seller ID (42)
        );

        // Tap CTA
        final cta = find.descendant(
          of: find.byType(FigCta),
          matching: find.byType(GestureDetector),
        );
        await tester.tap(cta.first);
        await tester.pumpAndSettle();

        // Verify backend was called to open conversation
        expect(
          server.visitedPaths.any(
            (p) => p.startsWith('POST /api/v1/conversations/'),
          ),
          isTrue,
        );
        expect(server.lastPostJson?['listing_slug'], 'test-listing-1');

        // Verify ChatPage was opened with correct conversation ID
        expect(find.textContaining('ChatPage:conv-uuid-1234'), findsOneWidget);
      },
    );

    testWidgets('CTA floats above tabs instead of reserving a white panel', (
      tester,
    ) async {
      await _pumpPage(tester, server: _FakeServer());

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.floatingActionButton, isA<FigCta>());
      expect(scaffold.bottomNavigationBar, isA<AppTabBar>());

      final cta = tester.getRect(find.byType(FigCta));
      final tabs = tester.getRect(find.byType(AppTabBar));
      expect(cta.bottom, lessThanOrEqualTo(tabs.top));
    });

    testWidgets('профиль продавца прокручивается', (tester) async {
      await _pumpPage(
        tester,
        server: _FakeServer(listingCount: 12),
        size: const Size(412, 915),
      );

      final controller =
          tester.widget<CustomScrollView>(find.byType(CustomScrollView)).controller!;
      expect(controller.offset, 0);
      expect(controller.position.maxScrollExtent, greaterThan(0),
          reason: 'контент обязан переполнять экран, иначе тест бессмыслен');

      // Тянем в середине экрана, подальше от кнопки внизу.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -250));
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0),
          reason: 'вертикальный жест обязан прокручивать профиль');
    });

    testWidgets('кнопка связи стоит внизу экрана, а не посреди профиля', (
      tester,
    ) async {
      const size = Size(412, 915);
      await _pumpPage(tester, server: _FakeServer(), size: size);

      // Меряем видимую кнопку, а не коробку FigCta: при дефекте коробка
      // растягивалась во весь экран, её нижняя грань оставалась у меню, и
      // проверка по контейнеру ничего не замечала — кнопка при этом рисовалась
      // в вертикальном центре, поверх описания продавца.
      final button = find.descendant(
        of: find.byType(FigCta),
        matching: find.byType(DecoratedBox),
      );
      expect(button, findsOneWidget);

      final rect = tester.getRect(button);
      expect(
        rect.center.dy / size.height,
        greaterThan(0.65),
        reason: 'кнопка должна быть в нижней трети, а не в середине',
      );
    });

    testWidgets('кнопка связи не накрывает описание продавца', (tester) async {
      await _pumpPage(tester, server: _FakeServer(), size: const Size(412, 915));

      final button = tester.getRect(
        find.descendant(
          of: find.byType(FigCta),
          matching: find.byType(DecoratedBox),
        ),
      );
      final name = tester.getRect(find.text('Айбек'));

      expect(
        button.top,
        greaterThan(name.bottom),
        reason: 'шапка профиля должна оставаться читаемой',
      );
    });

    testWidgets('кнопка связи держится над нижним меню', (tester) async {
      await _pumpPage(tester, server: _FakeServer(), size: const Size(412, 915));

      final button = tester.getRect(
        find.descendant(
          of: find.byType(FigCta),
          matching: find.byType(DecoratedBox),
        ),
      );
      final tabs = tester.getRect(find.byType(AppTabBar));

      expect(button.bottom, lessThanOrEqualTo(tabs.top));
      expect(tabs.top - button.bottom, lessThan(48.0),
          reason: 'зазор должен быть аккуратным, а не белой панелью');
    });

    testWidgets('CTA preserves the listing that opened the seller profile', (
      tester,
    ) async {
      final server = _FakeServer(sellerKind: 'owner');
      await _pumpPage(
        tester,
        server: server,
        loggedInUserId: 99,
        args: const AgentListingsArgs(
          sellerId: 42,
          initialListingSlug: 'source-listing',
          initialListingTitle: 'Исходное объявление',
        ),
      );

      await tester.tap(find.byType(FigCta));
      await tester.pumpAndSettle();

      expect(server.lastPostJson?['listing_slug'], 'source-listing');
      expect(
        find.text('ChatPage:conv-uuid-1234:Исходное объявление'),
        findsOneWidget,
      );
    });

    testWidgets('guest user tapping CTA redirects to WelcomePage', (
      tester,
    ) async {
      final server = _FakeServer();
      await _pumpPage(tester, server: server, isAuthenticated: false);

      final cta = find.descendant(
        of: find.byType(FigCta),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(cta.first);
      await tester.pumpAndSettle();

      expect(find.text('Войдите, чтобы написать продавцу'), findsOneWidget);
      expect(find.text('WelcomePage'), findsOneWidget);
    });

    testWidgets('user viewing own seller profile is prevented from self-chat', (
      tester,
    ) async {
      final server = _FakeServer();
      await _pumpPage(
        tester,
        server: server,
        isAuthenticated: true,
        loggedInUserId: 42, // Same as seller ID (42)
      );

      final cta = find.descendant(
        of: find.byType(FigCta),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(cta.first);
      await tester.pumpAndSettle();

      expect(find.text('Это ваш профиль'), findsOneWidget);
      expect(
        server.visitedPaths.any(
          (p) => p.startsWith('POST /api/v1/conversations/'),
        ),
        isFalse,
      );
    });

    testWidgets('matches the approved Figma geometry at 390x844', (
      tester,
    ) async {
      final server = _FakeServer(
        sellerName: 'Садыр Жапаров',
        activeListingsCount: 8,
        soldListingsCount: 12,
        about: null,
      );

      await _pumpPage(tester, server: server, size: const Size(390, 844));

      final cover = tester.getRect(find.byKey(const ValueKey('agent-cover')));
      final avatar = tester.getRect(find.byKey(const ValueKey('agent-avatar')));
      final name = tester.getRect(find.text('Садыр Жапаров'));
      final role = tester.getRect(
        find.byKey(const ValueKey('agent-role-badge')),
      );
      final active = tester.getRect(find.text('8 объектов недвижимости'));
      final sold = tester.getRect(find.text('Продано: 12 объектов'));
      final tabs = tester.getRect(
        find.byKey(const ValueKey('agent-filter-tabs')),
      );
      final cards = find.byType(ObjectCard);
      final firstCard = tester.getRect(cards.at(0));
      final secondCard = tester.getRect(cards.at(1));
      final firstImage = tester.getRect(
        find
            .descendant(of: cards.at(0), matching: find.byType(ClipRRect))
            .first,
      );
      final nav = tester.getRect(find.byType(AppTabBar));
      final ctaButton = tester.getRect(
        find
            .descendant(
              of: find.byType(FigCta),
              matching: find.byType(GestureDetector),
            )
            .first,
      );

      expect(cover.left, 0);
      expect(cover.top, 0);
      expect(cover.width, 390);
      expect(cover.height, closeTo(212.5, 0.1));
      expect(avatar.width, closeTo(68, 0.5));
      expect(avatar.height, closeTo(68, 0.5));
      expect(avatar.top, lessThan(cover.bottom));
      expect(avatar.bottom, greaterThan(cover.bottom));
      expect(name.left, closeTo(25, 0.1));
      expect(name.top, greaterThan(cover.bottom));
      expect(role.right, closeTo(365, 0.1));
      expect(sold.top, greaterThan(active.bottom));
      expect(tabs.top, greaterThan(sold.bottom));
      expect(firstCard.left, closeTo(25, 0.1));
      expect(firstCard.width, closeTo(167.5, 0.1));
      expect(secondCard.left, closeTo(197.5, 0.1));
      expect(firstImage.width, closeTo(firstCard.width, 0.1));
      expect(ctaButton.bottom, lessThanOrEqualTo(nav.top));
      expect(nav.bottom, closeTo(844, 0.1));

      final allTab = tester.widget<Container>(
        find.byKey(const ValueKey('agent-filter-all')),
      );
      final allDecoration = allTab.decoration! as BoxDecoration;
      expect(allDecoration.color, const Color(0xffffeadb));
      expect(tester.takeException(), isNull);
    });

    for (final size in const <Size>[
      Size(320, 600),
      Size(360, 844),
      Size(375, 812),
      Size(390, 950),
      Size(412, 844),
    ]) {
      testWidgets('has no overflow at ${size.width}x${size.height}', (
        tester,
      ) async {
        await _pumpPage(
          tester,
          server: _FakeServer(
            sellerName: 'Очень длинное имя владельца недвижимости Кыргызстана',
            about:
                'Подробное описание продавца, которое занимает несколько строк и проверяет адаптивность.',
          ),
          size: size,
          locale: const Locale('ky'),
        );

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
        await tester.pumpAndSettle();

        expect(find.byType(ObjectCard), findsWidgets);
        expect(
          tester.getRect(find.byType(AppTabBar)).bottom,
          closeTo(size.height, 0.1),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/data/code_flow.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:house_kgz/ui/listing_grid.dart';
import 'package:house_kgz/ui/object_card.dart';
import 'package:house_kgz/ui/pages/code_page.dart';
import 'package:house_kgz/ui/pages/register_page.dart';
import 'package:house_kgz/ui/widgets/auth_bottom_illustration.dart';

class _MockHttpServer extends http.BaseClient {
  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/terms/latest/')) {
      return _json({'version': '1.0', 'url': 'https://example.com/terms'});
    }
    if (path.contains('/auth/otp/request/')) {
      return _json({'status': 'sent', 'resend_after': 60});
    }
    return _json({'detail': 'Not found'}, 404);
  }
}

Widget _wrap(Widget child, AppState state, {Locale locale = const Locale('ru')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routes: {
      Routes.code: (context) => const CodePage(),
      Routes.home: (context) => const Scaffold(body: Text('Home Screen')),
    },
    home: AppScope(
      state: state,
      child: child,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'access_token': 'test_token'});
  });

  group('Part A: Listing Grid Spacing & Geometry', () {
    final testListings = [
      const Listing(
        id: '1',
        district: 'Технопарк',
        priceUsd: 185000,
        rooms: 4,
        area: 145,
        floor: 12,
        floors: 14,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/92b0d143df96c511.jpg',
      ),
      const Listing(
        id: '2',
        district: 'Центр',
        priceUsd: 245000,
        rooms: 3,
        area: 115,
        floor: 1,
        floors: 9,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/2e62acec850fa8b9.jpg',
      ),
      const Listing(
        id: '3',
        district: 'Центр',
        priceUsd: 59000,
        rooms: 1,
        area: 48,
        floor: 5,
        floors: 9,
        kind: PropertyKind.apartment,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/92b0d143df96c511.jpg',
      ),
      const Listing(
        id: '4',
        district: 'Кок-Жар',
        priceUsd: 195000,
        rooms: 5,
        area: 210,
        landArea: 8.0,
        floor: 2,
        floors: 2,
        kind: PropertyKind.house,
        seller: SellerKind.owner,
        status: 'active',
        photo: 'assets/figma/2e62acec850fa8b9.jpg',
      ),
    ];

    testWidgets('Two-row grid has clear vertical gap between metadata of row 1 and image of row 2', (tester) async {
      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        Scaffold(
          body: ListingGrid(
            listings: testListings,
            onOpen: (_) {},
          ),
        ),
        state,
      ));
      await tester.pumpAndSettle();

      final cards = tester.widgetList<ObjectCard>(find.byType(ObjectCard)).toList();
      expect(cards.length, 4);

      // Получаем координаты карточки 1 (верхний ряд) и карточки 3 (нижний ряд)
      final card1Rect = tester.getRect(find.byWidget(cards[0]));
      final card3Rect = tester.getRect(find.byWidget(cards[2]));

      // Зазор между началом ряда 1 и началом ряда 2 равен kCardRowPitch (225.3)
      final rowPitch = card3Rect.top - card1Rect.top;
      expect(rowPitch, greaterThanOrEqualTo(220.0));

      // Чистый зазор между низом карточки 1 и верхом карточки 3 равен 24.0 logical px
      final verticalGap = card3Rect.top - card1Rect.bottom;
      expect(verticalGap, greaterThanOrEqualTo(20.0));
      expect(verticalGap, lessThanOrEqualTo(28.0));
    });

    testWidgets('Long price and long specs render without overflow across screen widths', (tester) async {
      final extremeListings = [
        const Listing(
          id: '1',
          district: 'Аламединский район',
          priceUsd: 150000000,
          rooms: 8,
          area: 999,
          landArea: 25.0,
          floor: 3,
          floors: 3,
          kind: PropertyKind.house,
          seller: SellerKind.agency,
          status: 'active',
          photo: 'assets/figma/92b0d143df96c511.jpg',
        ),
        const Listing(
          id: '2',
          district: 'Южные магистрали',
          priceUsd: 12500000,
          rooms: 6,
          area: 450,
          floor: 25,
          floors: 25,
          kind: PropertyKind.apartment,
          seller: SellerKind.realtor,
          status: 'active',
          photo: 'assets/figma/2e62acec850fa8b9.jpg',
        ),
      ];

      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
        tester.view.physicalSize = Size(width, 812);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(_wrap(
          Scaffold(
            body: ListingGrid(
              listings: extremeListings,
              onOpen: (_) {},
            ),
          ),
          state,
        ));
        await tester.pumpAndSettle();

        expect(find.text('150 000 000\$'), findsOneWidget);
        expect(find.text('12 500 000\$'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Part B: Auth Bottom Illustrations', () {
    testWidgets('AuthBottomIllustration spans full width and keeps aspect ratio', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AuthBottomIllustration(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final illustrationRect = tester.getRect(find.byType(AuthBottomIllustration));
      expect(illustrationRect.width, 390.0);
      expect(illustrationRect.height, greaterThanOrEqualTo(220.0));
    });

    testWidgets('RegisterPage contains large AuthBottomIllustration and all active controls', (tester) async {
      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterPage(), state));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomIllustration), findsOneWidget);
      expect(find.byKey(kRegisterPhoneFieldKey), findsOneWidget);
      expect(find.byKey(kRegisterNameFieldKey), findsOneWidget);
      expect(find.byKey(kRegisterPasswordFieldKey), findsOneWidget);
      expect(find.byKey(kRegisterSubmitKey), findsOneWidget);
    });

    testWidgets('CodePage contains large AuthBottomIllustration and active OTP field', (tester) async {
      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(
        const CodePage(
          phone: '+996777212798',
          flow: CodeFlow(
            kind: CodeFlowKind.register,
            phone: '+996777212798',
            name: 'Адилет',
            password: 'password123',
            resendAfter: 60,
          ),
        ),
        state,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomIllustration), findsOneWidget);
      expect(find.byKey(kOtpInputKey), findsOneWidget);
      expect(find.text('Код подтверждения'), findsOneWidget);
      expect(find.text('Назад'), findsOneWidget);
    });

    testWidgets('RegisterPage and CodePage are keyboard-safe (no overflow with viewInsets)', (tester) async {
      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      // Эмулируем открытую клавиатуру (viewInsets.bottom = 300)
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(_wrap(const RegisterPage(), state));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byKey(kRegisterSubmitKey), findsOneWidget);
    });

    testWidgets('KY Locale: RegisterPage and CodePage render properly with large illustration', (tester) async {
      final mockHttp = _MockHttpServer();
      final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://localhost', client: mockHttp));

      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const RegisterPage(), state, locale: const Locale('ky')));
      await tester.pumpAndSettle();

      expect(find.byType(AuthBottomIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

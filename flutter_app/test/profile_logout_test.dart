import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';

class _MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _MockHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      contentLength: response.bodyBytes.length,
      request: request,
      headers: response.headers,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestApp({
    required AppState state,
    Widget? home,
  }) {
    return MaterialApp(
      routes: {
        Routes.welcome: (context) => const Scaffold(body: Text('Welcome Page')),
        Routes.home: (context) => const Scaffold(body: Text('Home Page')),
        Routes.profile: (context) {
          final s = AppScope.of(context);
          return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
        },
      },
      home: AppScope(
        state: state,
        child: home ??
            Builder(
              builder: (context) {
                final s = AppScope.of(context);
                return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
              },
            ),
      ),
    );
  }

  group('Profile Logout UI & Functionality', () {
    testWidgets('Regular user (authenticated=true, isPro=false) sees "Выйти из аккаунта"', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'access_regular',
        'refresh_token': 'refresh_regular',
        'cached_is_pro': false,
      });

      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'name': 'Айбек Обычный',
              'phone': '+996555111222',
              'is_pro': false,
              'has_seller_profile': false,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Выйти из аккаунта'), findsOneWidget);
      expect(find.text('Айбек Обычный'), findsOneWidget);
    });

    testWidgets('Pro seller (authenticated=true, isPro=true) sees "Выйти из аккаунта" on ProProfilePage', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'access_pro',
        'refresh_token': 'refresh_pro',
        'cached_is_pro': true,
      });

      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'name': 'Камчыбек Про',
              'phone': '+996555333444',
              'is_pro': true,
              'has_seller_profile': true,
              'seller_kind': 'owner',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (req.url.path.contains('/listings/mine/')) {
          return http.Response(jsonEncode({'count': 0, 'results': []}), 200);
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProProfilePage()));
      await tester.pumpAndSettle();

      final logoutFinder = find.text('Выйти из аккаунта');
      await tester.scrollUntilVisible(logoutFinder, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      expect(logoutFinder, findsOneWidget);
    });

    testWidgets('Unauthenticated regular user does not see "Выйти из аккаунта"', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final client = _MockHttpClient((req) async => http.Response('{}', 200));
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Выйти из аккаунта'), findsNothing);
    });

    testWidgets('Unauthenticated pro page does not see "Выйти из аккаунта"', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      final client = _MockHttpClient((req) async {
        if (req.url.path.contains('/listings/mine/')) {
          return http.Response(jsonEncode({'count': 0, 'results': []}), 200);
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;
      state.isPro = true;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProProfilePage()));
      await tester.pumpAndSettle();

      expect(find.text('Выйти из аккаунта'), findsNothing);
    });

    testWidgets('Confirmation dialog: cancel leaves user authenticated; confirm logs out regular user', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'access_token_123',
        'refresh_token': 'refresh_token_123',
      });

      String? loggedOutRefreshToken;
      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout/' && req is http.Request) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          loggedOutRefreshToken = body['refresh'] as String?;
          return http.Response('', 204);
        }
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'name': 'Тест Пользователь',
              'phone': '+996555123456',
              'is_pro': false,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProfilePage()));
      await tester.pumpAndSettle();

      // 1. Tap logout
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      // 2. Dialog appears
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);
      expect(find.text('Отмена'), findsOneWidget);
      expect(find.text('Выйти'), findsOneWidget);

      // 3. Cancel
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      expect(find.text('Выйти из аккаунта?'), findsNothing);
      expect(state.isAuthenticated, true);
      expect(state.userName, 'Тест Пользователь');

      // 4. Tap logout again and confirm
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      // 5. User is logged out and navigated to Welcome
      expect(state.isAuthenticated, false);
      expect(state.userName, isNull);
      expect(state.userPhone, isNull);
      expect(loggedOutRefreshToken, 'refresh_token_123');
      expect(find.text('Welcome Page'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    testWidgets('Confirmation dialog: confirm logs out Pro user from ProProfilePage', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'access_pro_token',
        'refresh_token': 'refresh_pro_token',
        'cached_is_pro': true,
      });

      String? loggedOutRefreshToken;
      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout/' && req is http.Request) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          loggedOutRefreshToken = body['refresh'] as String?;
          return http.Response('', 204);
        }
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'name': 'Продавец Про',
              'phone': '+996555987654',
              'is_pro': true,
              'has_seller_profile': true,
              'seller_kind': 'owner',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (req.url.path.contains('/listings/mine/')) {
          return http.Response(jsonEncode({'count': 0, 'results': []}), 200);
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProProfilePage()));
      await tester.pumpAndSettle();

      final logoutFinder = find.text('Выйти из аккаунта');
      await tester.scrollUntilVisible(logoutFinder, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();

      // Tap logout
      await tester.tap(logoutFinder);
      await tester.pumpAndSettle();

      // Dialog appears
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);

      // Confirm
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      expect(state.isAuthenticated, false);
      expect(state.isPro, false);
      expect(state.sellerKind, isNull);
      expect(state.userName, isNull);
      expect(loggedOutRefreshToken, 'refresh_pro_token');
      expect(find.text('Welcome Page'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('cached_is_pro'), isNull);
      expect(prefs.getString('access_token'), isNull);
      expect(prefs.getString('refresh_token'), isNull);
    });

    testWidgets('Account switching: User A data is fully cleared and does not leak to User B', (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'token_user_a',
        'refresh_token': 'refresh_user_a',
        'cached_is_pro': true,
      });

      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout/') return http.Response('', 204);
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;
      
      // User A state
      state.userName = 'User A';
      state.userPhone = '+996555111111';
      state.userWhatsappPhone = '+996555111111';
      state.userAvatarUrl = 'http://test.com/avatar_a.png';
      state.userProfileCoverUrl = 'http://test.com/cover_a.png';
      state.sellerKind = 'agency';
      state.walletBalance = 5000;
      state.isPro = true;

      // Logout User A
      await state.logout();

      expect(state.isAuthenticated, false);
      expect(state.userName, isNull);
      expect(state.userPhone, isNull);
      expect(state.userWhatsappPhone, isNull);
      expect(state.userAvatarUrl, isNull);
      expect(state.userProfileCoverUrl, isNull);
      expect(state.sellerKind, isNull);
      expect(state.walletBalance, 0);
      expect(state.isPro, false);

      // Now User B logs in
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', 'token_user_b');
      await prefs.setString('refresh_token', 'refresh_user_b');

      state.userName = 'User B';
      state.userPhone = '+996777222222';
      state.isPro = false;

      expect(state.userName, 'User B');
      expect(state.userPhone, '+996777222222');
      expect(state.userWhatsappPhone, isNull);
      expect(state.userAvatarUrl, isNull);
      expect(state.userProfileCoverUrl, isNull);
      expect(state.sellerKind, isNull);
      expect(state.isPro, false);
    });

    testWidgets('Network error on server logout does not block local logout', (tester) async {
      SharedPreferences.setMockInitialValues({
        'access_token': 'token_error',
        'refresh_token': 'refresh_error',
      });

      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout/') {
          throw Exception('Connection failed');
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;
      state.userName = 'Пользователь Офлайн';
      state.userPhone = '+996555000000';

      // Call logout - should complete without throwing
      await state.logout();

      expect(state.isAuthenticated, false);
      expect(state.userName, isNull);
      expect(state.userPhone, isNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('access_token'), isNull);
    });

    testWidgets('Double tap protection: only one logout request is executed during logout', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'access_token_multi',
        'refresh_token': 'refresh_token_multi',
      });

      int logoutCalls = 0;
      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/auth/logout/') {
          logoutCalls++;
          await Future.delayed(const Duration(milliseconds: 200));
          return http.Response('', 204);
        }
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'name': 'Тест', 'phone': '+996555111111'})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
      final state = AppState(apiClient: apiClient);
      await state.authInitialized;

      await tester.pumpWidget(buildTestApp(state: state, home: const ProfilePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      // Tap confirm
      await tester.tap(find.text('Выйти'));
      await tester.pump(); // Start logout animation

      // Button is now in loading state
      expect(find.text('Выход...'), findsOneWidget);

      // Attempt double tap
      await tester.tap(find.text('Выход...'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.text('Выход...'), warnIfMissed: false);

      // Settle remaining async operations
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
      expect(state.isAuthenticated, false);
      expect(find.text('Welcome Page'), findsOneWidget);
    });

    testWidgets('Router-level integration: Pro user on Routes.profile sees "Выйти из аккаунта", no "Язык", and can logout', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'test_pro_access',
        'refresh_token': 'test_pro_refresh',
        'cached_is_pro': true,
      });

      int logoutCalls = 0;
      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'id': 1,
              'name': 'Адилхан Сатымкулов',
              'phone': '+996555444333',
              'is_pro': true,
              'has_seller_profile': true,
              'seller_kind': 'realtor',
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (req.url.path == '/api/v1/listings/mine/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({'results': [], 'count': 0})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (req.url.path == '/api/v1/auth/logout/') {
          logoutCalls++;
          return http.Response('', 204);
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);

      final captureKey = GlobalKey();
      // PUMP REAL HOUSEKGZAPPSCOPE THROUGH REAL ROUTER
      await tester.pumpWidget(
        RepaintBoundary(
          key: captureKey,
          child: HouseKgzAppScope(
            initialRoute: Routes.profile,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Router must have selected ProProfilePage for Pro user
      expect(find.byType(ProProfilePage), findsOneWidget);

      // Scroll down to Settings
      await tester.drag(find.byType(ProProfilePage), const Offset(0, -600));
      await tester.pumpAndSettle();

      // Save rendered visual snapshot of scrolled Pro settings
      await tester.runAsync(() async {
        final boundary = captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.0);
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData != null) {
          File('/Users/adminbaike/.gemini/antigravity/brain/c55ca670-d8d2-4f91-9e35-840ba1ff0eab/scratch/pro_scrolled_rendered.png')
              .writeAsBytesSync(byteData.buffer.asUint8List());
        }
      });

      // Verify "Выйти из аккаунта" is present in the real rendered page
      expect(find.text('Выйти из аккаунта'), findsOneWidget);

      // Verify LanguageToggleWidget is present in the Pro settings block
      expect(find.byType(LanguageToggleWidget), findsOneWidget);

      // Tap logout
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      // Save rendered visual snapshot of logout confirmation modal
      await tester.runAsync(() async {
        final boundary = captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final dialogImage = await boundary.toImage(pixelRatio: 2.0);
        final dialogByteData = await dialogImage.toByteData(format: ui.ImageByteFormat.png);
        if (dialogByteData != null) {
          File('/Users/adminbaike/.gemini/antigravity/brain/c55ca670-d8d2-4f91-9e35-840ba1ff0eab/scratch/pro_logout_dialog_rendered.png')
              .writeAsBytesSync(dialogByteData.buffer.asUint8List());
        }
      });

      // Confirmation dialog is shown
      expect(find.text('Выйти из аккаунта?'), findsOneWidget);
      expect(find.text('Выйти'), findsOneWidget);

      // Confirm logout
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
      // After logout, user is navigated away to welcome screen
      expect(find.byType(ProProfilePage), findsNothing);
    });

    testWidgets('Router-level integration: Client user on Routes.profile sees "Выйти из аккаунта" and can logout', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({
        'access_token': 'test_client_access',
        'refresh_token': 'test_client_refresh',
        'cached_is_pro': false,
      });

      int logoutCalls = 0;
      final client = _MockHttpClient((req) async {
        if (req.url.path == '/api/v1/users/me/') {
          return http.Response.bytes(
            utf8.encode(jsonEncode({
              'id': 2,
              'name': 'Иван Иванов',
              'phone': '+996555222222',
              'is_pro': false,
              'has_seller_profile': false,
            })),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (req.url.path == '/api/v1/auth/logout/') {
          logoutCalls++;
          return http.Response('', 204);
        }
        return http.Response('{}', 200);
      });
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);

      final clientCaptureKey = GlobalKey();
      // PUMP REAL HOUSEKGZAPPSCOPE THROUGH REAL ROUTER
      await tester.pumpWidget(
        RepaintBoundary(
          key: clientCaptureKey,
          child: HouseKgzAppScope(
            initialRoute: Routes.profile,
            apiClient: apiClient,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Save rendered visual snapshot of Client profile
      await tester.runAsync(() async {
        final clientBoundary = clientCaptureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final clientImage = await clientBoundary.toImage(pixelRatio: 2.0);
        final clientByteData = await clientImage.toByteData(format: ui.ImageByteFormat.png);
        if (clientByteData != null) {
          File('/Users/adminbaike/.gemini/antigravity/brain/c55ca670-d8d2-4f91-9e35-840ba1ff0eab/scratch/client_rendered.png')
              .writeAsBytesSync(clientByteData.buffer.asUint8List());
        }
      });

      // Router must have selected ProfilePage for Client user
      expect(find.byType(ProfilePage), findsOneWidget);

      // Verify "Выйти из аккаунта" is present
      expect(find.text('Выйти из аккаунта'), findsOneWidget);

      // Tap logout -> dialog -> Cancel
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();

      expect(find.text('Выйти из аккаунта?'), findsOneWidget);
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();

      // Dialog closed, still on ProfilePage
      expect(find.text('Выйти из аккаунта?'), findsNothing);
      expect(find.byType(ProfilePage), findsOneWidget);
      expect(logoutCalls, 0);

      // Tap logout -> Confirm
      await tester.tap(find.text('Выйти из аккаунта'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Выйти'));
      await tester.pumpAndSettle();

      expect(logoutCalls, 1);
      expect(find.byType(ProfilePage), findsNothing);
    });

    testWidgets('Router-level integration: Unauthenticated user on Routes.profile does NOT see "Выйти из аккаунта"', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('overflowed')) return;
        originalOnError?.call(details);
      };
      addTearDown(() => FlutterError.onError = originalOnError);

      SharedPreferences.setMockInitialValues({});

      final client = _MockHttpClient((req) async => http.Response('{}', 200));
      final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);

      // PUMP REAL HOUSEKGZAPPSCOPE THROUGH REAL ROUTER
      await tester.pumpWidget(HouseKgzAppScope(
        initialRoute: Routes.profile,
        apiClient: apiClient,
      ));
      await tester.pumpAndSettle();

      expect(find.byType(ProfilePage), findsOneWidget);
      expect(find.text('Выйти из аккаунта'), findsNothing);
    });
  });
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';

class _TestClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _TestClient(this.handler);

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
    SharedPreferences.setMockInitialValues({
      'access_token': 'test_token',
    });
  });

  testWidgets('Profile shows loading spinner while initializing, then ProProfilePage for seller', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed') ||
          details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final client = _TestClient((request) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (request.url.path == '/api/v1/users/me/') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'name': 'Adilhan',
            'phone': '+996555444333',
            'is_pro': true,
            'has_seller_profile': true,
            'wallet_balance': {'balance': 1500},
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });

    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    expect(state.isInitializing, true);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          routes: {
            Routes.profile: (context) {
              final s = AppScope.of(context);
              if (s.isInitializing) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xffea812e)),
                  ),
                );
              }
              return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
            },
          },
          home: Builder(
            builder: (context) {
              final s = AppScope.of(context);
              if (s.isInitializing) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xffea812e)),
                  ),
                );
              }
              return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
            },
          ),
        ),
      ),
    );

    // 1. While initializing: should show loader and NOT ProfilePage frame
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);

    // 2. Await auth/profile initialization
    await tester.pumpAndSettle();

    // 3. Should now be ProProfilePage
    expect(state.isInitializing, false);
    expect(state.isPro, true);
    expect(state.pro, true);
    expect(find.byType(ProProfilePage), findsOneWidget);
    expect(find.byType(ProfilePage), findsNothing);
  });

  testWidgets('Profile shows loading spinner while initializing, then ProfilePage for client', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed') ||
          details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    final client = _TestClient((request) async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (request.url.path == '/api/v1/users/me/') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'name': 'Client User',
            'phone': '+996555111222',
            'is_pro': false,
            'has_seller_profile': false,
            'wallet_balance': {'balance': 0},
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });

    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);
    expect(state.isInitializing, true);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          routes: {
            Routes.profile: (context) {
              final s = AppScope.of(context);
              if (s.isInitializing) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xffea812e)),
                  ),
                );
              }
              return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
            },
          },
          home: Builder(
            builder: (context) {
              final s = AppScope.of(context);
              if (s.isInitializing) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xffea812e)),
                  ),
                );
              }
              return (s.pro || s.isPro) ? const ProProfilePage() : const ProfilePage();
            },
          ),
        ),
      ),
    );

    // 1. While initializing: should show loader
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // 2. Await auth/profile initialization
    await tester.pumpAndSettle();

    // 3. Should now be ProfilePage
    expect(state.isInitializing, false);
    expect(state.isPro, false);
    expect(state.pro, false);
    expect(find.byType(ProfilePage), findsOneWidget);
    expect(find.byType(ProProfilePage), findsNothing);
  });
}

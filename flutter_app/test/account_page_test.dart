import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/account_page.dart';
import 'package:house_kgz/ui/widgets/profile_identity.dart';

class _MockClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _MockClient(this.handler);

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

  testWidgets('AccountPage displays user profile with cover and avatar, opens password change', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool passwordChangeCalled = false;

    final client = _MockClient((request) async {
      if (request.url.path == '/api/v1/users/me/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'name': 'Адилет Султанов',
            'phone': '+996555123456',
            'is_pro': false,
            'seller_kind': 'owner',
            'avatar_url': 'http://test.com/media/avatar.png',
            'cover_url': 'http://test.com/media/cover.png',
            'profile_cover_url': 'http://test.com/media/cover.png',
            'wallet_balance': {'balance': 1200},
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/auth/password/change/' && request.method == 'POST') {
        passwordChangeCalled = true;
        return http.Response.bytes(
          utf8.encode(jsonEncode({'message': 'Пароль успешно изменён.'})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('{}', 200);
    });

    final apiClient = ListingApiClient(baseUrl: 'http://test.com', client: client);
    final state = AppState(apiClient: apiClient);

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AccountPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Проверяем отображение имени, телефона и плашек
    expect(find.text('Адилет Султанов'), findsWidgets);
    expect(find.text('+996555123456'), findsOneWidget);
    expect(find.byType(ProfileCover), findsOneWidget);
    expect(find.byType(ProfileAvatar), findsOneWidget);

    // Проверяем наличие кнопок управления аватаром и обложкой
    expect(find.text('Фото профиля'), findsOneWidget);
    expect(find.text('Фон профиля'), findsOneWidget);

    // Открываем смену пароля
    final changePasswordBtn = find.text('Изменить пароль');
    expect(changePasswordBtn, findsOneWidget);
    await tester.tap(changePasswordBtn);
    await tester.pumpAndSettle();

    // Проверяем, что открылась шторка смены пароля
    expect(find.text('Смена пароля'), findsOneWidget);
    expect(find.text('Сохранить пароль'), findsOneWidget);

    // Вводим новый пароль
    final textFields = find.byType(TextField);
    // 3 поля: текущий пароль, новый, повтор
    expect(textFields, findsNWidgets(3));

    await tester.enterText(textFields.at(0), 'old_pass_123');
    await tester.enterText(textFields.at(1), 'new_super_pass_456');
    await tester.enterText(textFields.at(2), 'new_super_pass_456');

    await tester.tap(find.text('Сохранить пароль'));
    await tester.pumpAndSettle();

    expect(passwordChangeCalled, true);
    expect(find.text('Пароль успешно изменён!'), findsOneWidget);
  });

  testWidgets('AccountPage allows editing name and whatsapp phone', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? updatedName;
    String? updatedWhatsapp;

    final client = _MockClient((request) async {
      if (request.url.path == '/api/v1/users/me/' && request.method == 'GET') {
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'name': 'Иван Иванов',
            'phone': '+996555123456',
            'whatsapp_phone': '+996700112233',
            'is_pro': false,
            'seller_kind': 'owner',
            'avatar_url': null,
            'cover_url': null,
            'profile_cover_url': null,
            'wallet_balance': {'balance': 0},
          })),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/v1/users/me/' && request.method == 'PATCH') {
        final body = jsonDecode(utf8.decode((request as http.Request).bodyBytes)) as Map<String, dynamic>;
        if (body.containsKey('name')) {
          updatedName = body['name'];
        }
        if (body.containsKey('whatsapp_phone')) {
          updatedWhatsapp = body['whatsapp_phone'];
        }
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'name': updatedName ?? 'Иван Иванов',
            'phone': '+996555123456',
            'whatsapp_phone': updatedWhatsapp ?? '+996700112233',
            'is_pro': false,
            'seller_kind': 'owner',
            'avatar_url': null,
            'cover_url': null,
            'profile_cover_url': null,
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

    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(
          home: AccountPage(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // 1. Проверяем отображение текущего имени и WhatsApp
    expect(find.text('Иван Иванов'), findsWidgets);
    expect(find.text('+996700112233'), findsOneWidget);

    // 2. Редактируем WhatsApp
    await tester.tap(find.text('+996700112233'));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать: WhatsApp для связи'), findsOneWidget);
    final dialogField = find.byType(TextField).last;
    await tester.enterText(dialogField, '+996700998877');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(updatedWhatsapp, '+996700998877');
    expect(find.text('+996700998877'), findsOneWidget);
  });
}

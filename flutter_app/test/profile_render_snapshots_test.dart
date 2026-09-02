import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/data/api_client.dart';
import 'package:house_kgz/ui/pages/notifications_page.dart';
import 'package:house_kgz/ui/pages/profile_page.dart';
import 'package:house_kgz/ui/pages/pro_profile_page.dart';

class _SnapshotsMockServer extends http.BaseClient {
  _SnapshotsMockServer({this.notifications = const []});
  final List<Map<String, dynamic>> notifications;

  http.StreamedResponse _json(Object body, [int status = 200]) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/api/v1/users/me/')) {
      return _json({
        'id': 1,
        'phone': '+996555123456',
        'name': 'Садыр Жапаров',
        'is_pro': false,
        'role': 'client',
      });
    }
    if (path.contains('/api/v1/notifications/unread-count/')) return _json({'count': 0});
    if (path.contains('/api/v1/notifications/read/')) return _json({'status': 'ok'});
    if (path.contains('/api/v1/notifications/')) {
      return _json({
        'count': notifications.length,
        'next': null,
        'previous': null,
        'results': notifications,
      });
    }
    if (path.contains('/api/v1/listings/me/')) {
      return _json({
        'count': 3,
        'results': [
          {
            'id': 101,
            'slug': 'novostroyka-center',
            'title': '3-к квартира в ЖК Premiere',
            'price': '95000',
            'currency': 'USD',
            'address': 'ул. Токтогула 125',
            'rooms': 3,
            'area': 94.0,
            'floor': 7,
            'floors': 14,
            'kind': 'new_building',
            'seller_kind': 'owner',
            'status': 'active',
            'cover_photo': 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=600',
          }
        ],
      });
    }
    return _json({'results': []});
  }
}

Future<void> _capture(GlobalKey key, String name) async {
  final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData != null) {
    File('/Users/adminbaike/.gemini/antigravity/brain/c55ca670-d8d2-4f91-9e35-840ba1ff0eab/scratch/$name.png')
        .writeAsBytesSync(byteData.buffer.asUint8List());
  }
}

void main() {
  testWidgets('Capture Client & Pro Profile Snapshots', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'refresh_token': 'refresh',
      'user_phone': '+996555123456',
      'user_name': 'Садыр Жапаров',
    });

    final key = GlobalKey();
    final server = _SnapshotsMockServer(
      notifications: [
        {
          'id': 1,
          'type': 'new_message',
          'title': 'Новое сообщение от риелтора',
          'body': 'Здравствуйте! Объект доступен к просмотру сегодня в 17:00.',
          'is_read': false,
          'created_at': '2026-09-02T14:30:00Z',
        },
        {
          'id': 2,
          'type': 'price_drop',
          'title': 'Цена снижена на 1-к квартиру',
          'body': 'Стоимость квартиры в 7 мкр снизилась на 2 000 USD',
          'is_read': true,
          'created_at': '2026-09-02T11:15:00Z',
        },
      ],
    );

    final state = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: server));

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: key,
          child: AppScope(
            state: state,
            child: const ProfilePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async => _capture(key, 'profile_client_clean_layout'));

    // Pro Profile test
    final proKey = GlobalKey();
    final proServer = _SnapshotsMockServer(
      notifications: [
        {
          'id': 10,
          'type': 'new_message',
          'title': 'Отклик на новостройку ЖК Premiere',
          'body': 'Покупатель интересуется условиями рассрочки и планировкой 3-к квартиры.',
          'is_read': false,
          'created_at': '2026-09-02T13:00:00Z',
        },
      ],
    );

    SharedPreferences.setMockInitialValues({
      'access_token': 'token',
      'refresh_token': 'refresh',
      'is_pro': true,
      'user_phone': '+996555123456',
      'user_name': 'Садыр Жапаров',
    });

    final proState = AppState(apiClient: ListingApiClient(baseUrl: 'http://test', client: proServer));

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: proKey,
          child: AppScope(
            state: proState,
            child: const ProProfilePage(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.runAsync(() async => _capture(proKey, 'profile_pro_clean_layout'));
  });
}

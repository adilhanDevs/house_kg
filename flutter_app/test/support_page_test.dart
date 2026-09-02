import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/ui/pages/support_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  late List<String> openedUrls;

  setUp(() {
    openedUrls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'launch') {
            openedUrls.add(
              (call.arguments as Map<Object?, Object?>)['url']! as String,
            );
            return true;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('Telegram opens the existing support bot', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    while (tester.takeException() != null) {}

    await tester.tap(find.text('Telegram'));
    await tester.pump();

    expect(openedUrls, ['https://t.me/house_kg_bot']);
  });

  testWidgets('phone opens the system dialer', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SupportPage()));
    while (tester.takeException() != null) {}

    await tester.tap(find.text('Позвонить'));
    await tester.pump();

    expect(openedUrls, ['tel:+996312998877']);
  });
}

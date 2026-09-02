import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/prototype.dart';

void main() {
  for (final number in const ['15', '38']) {
    testWidgets('кадр $number', (tester) async {
      tester.view.physicalSize = const Size(375, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final screen = figScreens.firstWhere((s) => s.number == number);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: screen.width,
              height: screen.height,
              child: Builder(builder: (context) => Stack(children: [screen.builder(context)])),
            ),
          ),
        ),
      ));
      await tester.pump();

      for (final needle in const [
        'Последние уведомления',
        'Посмотреть все',
        'Цена снизилась',
        'Технопарк',
        'Настройки',
      ]) {
        final found = find.textContaining(needle);
        for (var i = 0; i < found.evaluate().length && i < 4; i++) {
          debugPrint('FRAME$number "$needle" #$i ${tester.getRect(found.at(i))}');
        }
      }
    });
  }
}

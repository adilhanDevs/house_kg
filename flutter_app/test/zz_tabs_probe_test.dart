import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';

void ignoreFlexOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (!details.exceptionAsString().contains('overflowed by')) {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
}

Future<void> report(WidgetTester tester, List<String> labels, String lang) async {
  for (final label in labels) {
    final f = find.text(label);
    if (f.evaluate().isEmpty) {
      // ignore: avoid_print
      print('[$lang] "$label" НЕ НАЙДЕН');
      continue;
    }
    final box = tester.renderObject<RenderBox>(f.first);
    final pos = box.localToGlobal(Offset.zero);
    // ignore: avoid_print
    print('[$lang] "$label" x=${pos.dx.toStringAsFixed(1)} '
        'y=${pos.dy.toStringAsFixed(1)} w=${box.size.width.toStringAsFixed(1)}');
  }
}

void main() {
  testWidgets('позиции вкладок «Новых позиций»', (tester) async {
    ignoreFlexOverflow();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const HouseKgzAppScope(initialRoute: Routes.home));
    await tester.pumpAndSettle();

    await report(tester, ['Квартиры', 'Участки', 'Дома'], 'ru');

    final ctx = tester.element(find.byType(Navigator).first);
    await AppScope.read(ctx).setLanguageCode('ky');
    await tester.pumpAndSettle();

    await report(tester, ['Батирлер', 'Жер тилкелери', 'Үйлөр'], 'ky');
  });
}

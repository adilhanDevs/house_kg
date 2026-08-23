// Полоса под навигацией Android: содержимое не должно попадать под кнопки.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/data/listings.dart';
import 'package:house_kgz/ui/app_tab_bar.dart';
import 'package:house_kgz/ui/pages/photos_page.dart';
import 'package:house_kgz/ui/pages/view_history_page.dart';

/// Полоса трёх кнопок навигации Android.
const double _nav = 48.0;

void _android(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  const bars = FakeViewPadding(top: 96, bottom: _nav * 3);
  tester.view.padding = bars;
  tester.view.viewPadding = bars;
  tester.view.viewInsets = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

double _height(WidgetTester tester) =>
    tester.view.physicalSize.height / tester.view.devicePixelRatio;

/// В тестах текст рисуется квадратным шрифтом Ahem — он шире настоящего, и
/// строки об объекте вылезают из своих рядов. К положению по вертикали это
/// отношения не имеет, поэтому такие жалобы пропускаем.
void _ignoreOverflow() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    previous?.call(details);
  };
  addTearDown(() => FlutterError.onError = previous);
}

Widget _wrap(Widget child) =>
    AppScope(state: AppState(), child: MaterialApp(home: child));

void main() {
  testWidgets('подписи нижнего меню не заходят под кнопки навигации',
      (tester) async {
    _android(tester);
    await tester.pumpWidget(_wrap(const ViewHistoryPage()));
    await tester.pump();

    final safeBottom = _height(tester) - _nav;
    // подписи вкладок — самое нижнее, что рисует меню
    expect(tester.getRect(find.text('Профиль')).bottom,
        lessThanOrEqualTo(safeBottom));
    // а белый фон под ними уходит до самого низа экрана
    expect(tester.getRect(find.byType(AppTabBar)).bottom, _height(tester));
  });

  testWidgets('«Вернуться» в фотообзоре не заходит под кнопки навигации',
      (tester) async {
    _android(tester);
    _ignoreOverflow();
    await tester.pumpWidget(_wrap(PhotosPage(id: kListings.first.id)));
    await tester.pump();

    expect(tester.getRect(find.bySemanticsLabel('Вернуться')).bottom,
        lessThanOrEqualTo(_height(tester) - _nav));
  });

  testWidgets('на кадрах макета полоса не удваивается', (tester) async {
    _android(tester);
    await tester.pumpWidget(const HouseKgzAppScope(initialRoute: Routes.home));
    await tester.pumpAndSettle();

    final safeBottom = _height(tester) - _nav;
    // сцена сама держит полосу, поэтому меню кончается ровно на её границе —
    // и не прибавляет к ней вторую
    final bar = tester.getRect(find.byType(AppTabBar));
    expect(bar.bottom, closeTo(safeBottom, 0.5));
    expect(bar.height, closeTo(kTabBarHeight * (360 / 375), 0.5));
  });
}

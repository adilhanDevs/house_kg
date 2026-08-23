// Кадры во весь экран без чужих полей и автопереход со сплэша.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app.dart';
import 'package:house_kgz/app/routes.dart';
import 'package:house_kgz/app/stage.dart';
import 'package:house_kgz/prototype.dart';
import 'package:house_kgz/ui/pages/onboarding_page.dart';
import 'package:house_kgz/ui/pages/splash_page.dart';

/// Шумы кадров, к безопасной области отношения не имеющие: подставной шрифт
/// теста шире SF Pro, а таб-бар макета рисует рамку с неоднородным цветом.
void ignoreFrameNoise() {
  const noise = ['overflowed by', 'borderRadius can only be given'];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.exceptionAsString();
    if (!noise.any(text.contains)) {
      previous?.call(details);
    }
  };
  addTearDown(() => FlutterError.onError = previous);
}

void main() {
  testWidgets('сплэш сам уходит на онбординг через две секунды', (tester) async {
    ignoreFrameNoise();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HouseKgzAppScope(initialRoute: Routes.splash));
    await tester.pump();
    expect(find.byType(SplashPage), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1900));
    expect(find.byType(OnboardingPage), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    expect(find.byType(SplashPage), findsNothing);
    expect(find.byType(OnboardingPage), findsOneWidget);
  });

  testWidgets('сверху поле кадра, снизу поле системы', (tester) async {
    ignoreFrameNoise();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const HouseKgzAppScope(initialRoute: Routes.catalog));
    await tester.pumpAndSettle();

    // Сверху система рисует статус-бар поверх пустой полосы кадра, а не над
    // ней; снизу кадр не залезает под навбар.
    final scroll = tester.getRect(find.byType(SingleChildScrollView).first);
    expect(scroll.top, 0.0);
    expect(scroll.bottom, 812.0 - 34.0);
  });

  testWidgets('свои часы и иконки убраны из всех кадров', (tester) async {
    ignoreFrameNoise();
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final screen in figScreens) {
      await tester.pumpWidget(
        MaterialApp(home: FigStage(frame: screen, background: Colors.white)),
      );
      await tester.pump();
      expect(
        find.text('12:48'),
        findsNothing,
        reason: 'кадр ${screen.number} «${screen.title}» рисует свой статус-бар',
      );
    }
  });
}

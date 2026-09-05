import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/ui/pages/ad_promo_page.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Widget buildApp(AppState state, Locale locale) {
    return AppScope(
      state: state,
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AdPromoPage()),
      ),
    );
  }

  testWidgets('AdPromoPage layout and l10n logic in KY/RU', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();

    // 1. Render in KY at 360x800
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(buildApp(state, const Locale('ky')));
    await tester.pumpAndSettle();

    // D. Saturn placeholder absent
    expect(find.textContaining('Сатурн'), findsNothing);
    expect(find.textContaining('Юпитер'), findsNothing);
    expect(find.textContaining('планета'), findsNothing);

    // C. KY contains no major Russian labels
    expect(find.text('Продвижение'), findsNothing);

    // B. all main labels KY
    expect(find.text('Жарыяны илгерилетүү'), findsWidgets);
    expect(find.text('Жарыяңызды көбүрөөк колдонуучу көрүшү үчүн илгерилетиңиз.'), findsWidgets);
    
    // E. amount placeholder KY
    // By default, Bricks is selected (reference state), so we should NOT see the placeholder.
    expect(find.text('Сумманы киргизиңиз'), findsNothing);

    // switch to Topup
    await tester.tap(find.text('Капчыкты толуктоо'));
    await tester.pumpAndSettle();
    expect(find.text('Сумманы киргизиңиз'), findsWidgets);

    // F. days placeholder KY
    expect(find.text('Күндөрдүн санын киргизиңиз'), findsWidgets);

    // G. primary CTA = Кийинки
    final nextBtn = find.text('Кийинки');
    await tester.dragUntilVisible(nextBtn, find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(nextBtn, findsWidgets);

    // H. secondary CTA = Илгерилетпей улантуу
    final skipBtn = find.text('Илгерилетпей улантуу');
    await tester.dragUntilVisible(skipBtn, find.byType(CustomScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(skipBtn, findsWidgets);

    // Check cost summary
    expect(find.textContaining('Чегерилет:'), findsWidgets);

    // Switch to RU
    await tester.pumpWidget(buildApp(state, const Locale('ru')));
    await tester.pumpAndSettle();

    // A. locale RU -> Russian Promotion labels
    expect(find.text('Продвижение'), findsWidgets);
    expect(find.text('Далее'), findsWidgets);
    expect(find.text('Продолжить без продвижения'), findsWidgets);
  });
}

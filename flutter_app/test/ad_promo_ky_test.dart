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
    // By default, Topup is selected, so we should see the placeholder.
    expect(find.text('Сумманы киргизиңиз'), findsWidgets);

    // switch to Bricks
    await tester.tap(find.text('Кирпичтерди колдонуу'));
    await tester.pumpAndSettle();
    expect(find.text('Сумманы киргизиңиз'), findsNothing);

    // F. days placeholder KY
    expect(find.text('Күндөрдүн санын киргизиңиз'), findsWidgets);

    // G. primary CTA = Кийинки
    expect(find.text('Кийинки'), findsWidgets);

    // H. secondary CTA = Илгерилетпей улантуу
    expect(find.text('Илгерилетпей улантуу'), findsWidgets);

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

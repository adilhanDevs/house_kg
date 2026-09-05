import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/ui/pages/ad_form_page.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AdFormPage renders in Kyrgyz without unnatural strings and Russian leftovers', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = AppState();
    
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(
          locale: const Locale('ky'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AdFormPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify UI placeholders and labels that are always visible
    expect(find.textContaining('Өзүңүздүн маани'), findsNothing);
    expect(find.text('Введите свою квадратуру...'), findsNothing);
    expect(find.text('Адрес'), findsNothing);
    expect(find.text('Подробнее об объекте'), findsNothing);
    expect(find.text('Болгон бөлмөлөрдү гана кошуңуз'), findsNothing);
    expect(find.text('Негизги жерлер'), findsNothing);

    // Ensure we don't have RU left
    expect(find.text('Адрес'), findsNothing);
    expect(find.text('Квартиры'), findsNothing);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/app/app_state.dart';
import 'package:house_kgz/ui/pages/ad_form_page.dart';
import 'package:house_kgz/l10n/l10n.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('AdFormPage renders in Kyrgyz without hardcoded Russian strings', (WidgetTester tester) async {
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

    expect(find.text('Выберите район'), findsNothing);
    expect(find.text('Квартиры'), findsNothing);
    expect(find.text('Дома'), findsNothing);

    expect(find.text('Батирлер'), findsWidgets);
  });
}

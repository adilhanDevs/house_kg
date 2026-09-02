import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:house_kgz/fig/tab_bar.dart';
import 'package:house_kgz/l10n/app_localizations.dart';
import 'package:house_kgz/ui/app_tab_bar.dart';

Widget _buildTestApp({
  required Locale locale,
  required double width,
  int? active,
  void Function(int)? onTap,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: AppTabBar(active: active),
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTabBar Geometry and Alignment Tests', () {
    final locales = [
      const Locale('ru'),
      const Locale('ky'),
    ];
    final widths = [320.0, 375.0, 390.0];

    for (final locale in locales) {
      for (final width in widths) {
        testWidgets('Icon and label centers match exactly for locale=${locale.languageCode} on width=$width', (tester) async {
          tester.view.physicalSize = Size(width * 2, 600 * 2);
          tester.view.devicePixelRatio = 2.0;
          addTearDown(() => tester.view.resetPhysicalSize());

          await tester.pumpWidget(_buildTestApp(locale: locale, width: width, active: 4));
          await tester.pumpAndSettle();

          expect(find.byType(FigTabBar), findsOneWidget);

          for (int i = 0; i < 5; i++) {
            final iconFinder = find.byKey(Key('tab_bar_icon_$i'));
            final labelFinder = find.byKey(Key('tab_bar_label_$i'));
            final itemFinder = find.byKey(Key('tab_bar_item_$i'));

            expect(iconFinder, findsOneWidget, reason: 'Icon $i not found');
            expect(labelFinder, findsOneWidget, reason: 'Label $i not found');
            expect(itemFinder, findsOneWidget, reason: 'Item $i not found');

            final iconRect = tester.getRect(iconFinder);
            final labelRect = tester.getRect(labelFinder);
            final itemRect = tester.getRect(itemFinder);

            final iconCenterX = iconRect.center.dx;
            final labelCenterX = labelRect.center.dx;
            final itemCenterX = itemRect.center.dx;

            // Difference between icon center and label center must be <= 1.0 px
            final diffIconLabel = (iconCenterX - labelCenterX).abs();
            final diffIconItem = (iconCenterX - itemCenterX).abs();

            expect(
              diffIconLabel,
              lessThanOrEqualTo(1.0),
              reason: 'Tab $i on ${locale.languageCode} (w=$width): iconCenterX=$iconCenterX, labelCenterX=$labelCenterX, diff=$diffIconLabel',
            );

            expect(
              diffIconItem,
              lessThanOrEqualTo(1.0),
              reason: 'Tab $i on ${locale.languageCode} (w=$width): iconCenterX=$iconCenterX, itemCenterX=$itemCenterX',
            );
          }
        });
      }
    }

    testWidgets('Active tab change does not alter icon and label horizontal centers', (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final Map<int, List<double>> iconCentersByActive = {};
      final Map<int, List<double>> labelCentersByActive = {};

      for (int active = 0; active < 5; active++) {
        await tester.pumpWidget(_buildTestApp(locale: const Locale('ru'), width: 375.0, active: active));
        await tester.pumpAndSettle();

        final iconCenters = <double>[];
        final labelCenters = <double>[];
        for (int i = 0; i < 5; i++) {
          iconCenters.add(tester.getRect(find.byKey(Key('tab_bar_icon_$i'))).center.dx);
          labelCenters.add(tester.getRect(find.byKey(Key('tab_bar_label_$i'))).center.dx);
        }
        iconCentersByActive[active] = iconCenters;
        labelCentersByActive[active] = labelCenters;
      }

      // Check that geometry is 100% stable regardless of which tab is active
      for (int active = 1; active < 5; active++) {
        for (int i = 0; i < 5; i++) {
          expect(iconCentersByActive[active]![i], equals(iconCentersByActive[0]![i]));
          expect(labelCentersByActive[active]![i], equals(labelCentersByActive[0]![i]));
        }
      }
    });

    testWidgets('Vertical gap between icon and label is uniform across all 5 tabs', (tester) async {
      tester.view.physicalSize = const Size(375 * 2, 600 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(_buildTestApp(locale: const Locale('ky'), width: 375.0, active: 0));
      await tester.pumpAndSettle();

      final gaps = <double>[];
      for (int i = 0; i < 5; i++) {
        final iconRect = tester.getRect(find.byKey(Key('tab_bar_icon_$i')));
        final labelRect = tester.getRect(find.byKey(Key('tab_bar_label_$i')));
        gaps.add(labelRect.top - iconRect.bottom);
      }

      for (int i = 1; i < 5; i++) {
        expect(
          (gaps[i] - gaps[0]).abs(),
          lessThanOrEqualTo(0.5),
          reason: 'Vertical gap mismatch between tab 0 (${gaps[0]}) and tab $i (${gaps[i]})',
        );
      }
    });

    testWidgets('Tapping each tab calls onTap with correct index', (tester) async {
      int? tappedIndex;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FigTabBar(
              active: 0,
              onTap: (index) => tappedIndex = index,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        await tester.tap(find.byKey(Key('tab_bar_item_$i')));
        await tester.pump();
        expect(tappedIndex, equals(i));
      }
    });
  });
}

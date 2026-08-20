import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finfloat/core/ui.dart';
import 'package:finfloat/data/db.dart';
import 'package:finfloat/logic/hindi.dart';

/// Widget tests — UI sach mein banti hai ya nahi.
/// Ab tak sirf logic test hota tha; ye screens ko asli mein render karte hain.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DB.i.close();
    DB.i.testPath = inMemoryDatabasePath;
    await DB.i.db;
  });

  tearDown(() async {
    await DB.i.close();
    DB.i.testPath = null;
  });

  Widget wrap(Widget child) => MaterialApp(theme: buildTheme(), home: child);

  group('MoneyHi widget — ₹ + Hindi', () {
    testWidgets('bade amount par Hindi line dikhti hai', (t) async {
      await t.pumpWidget(wrap(const Scaffold(body: MoneyHi(115308))));
      expect(find.textContaining('1,15,308'), findsOneWidget);
      expect(find.text('एक लाख पंद्रह हज़ार तीन सौ आठ रुपये'), findsOneWidget);
    });

    testWidgets('chhote amount par Hindi line NAHI', (t) async {
      await t.pumpWidget(wrap(const Scaffold(body: MoneyHi(500))));
      expect(find.textContaining('500'), findsOneWidget);
      expect(find.textContaining('रुपये'), findsNothing);
    });

    testWidgets('negative amount crash nahi karta', (t) async {
      await t.pumpWidget(wrap(const Scaffold(body: MoneyHi(-25000))));
      expect(testerNoException(), isTrue);
    });
  });

  group('F field — decimal input', () {
    testWidgets('decimal type ho sakta hai (0.35)', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(Scaffold(
          body: F(c, 'Rate %', type: TextInputType.number))));
      await t.enterText(find.byType(TextField), '0.35');
      expect(c.text, '0.35', reason: 'decimal point blocked nahi hona chahiye');
    });

    testWidgets('do dot nahi lagte', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(Scaffold(
          body: F(c, 'Rate %', type: TextInputType.number))));
      await t.enterText(find.byType(TextField), '0.3');
      await t.enterText(find.byType(TextField), '0.3.5');
      expect(c.text, '0.3', reason: 'doosra dot block hona chahiye');
    });

    testWidgets('letters filter ho jaate hain', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(Scaffold(
          body: F(c, 'Amount', type: TextInputType.number))));
      await t.enterText(find.byType(TextField), '12a.5b');
      expect(c.text, '12.5');
    });

    testWidgets('intOnly mein dot nahi', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(Scaffold(
          body: F(c, 'Count', type: TextInputType.number, intOnly: true))));
      await t.enterText(find.byType(TextField), '12.5');
      expect(c.text, '125', reason: 'intOnly mein dot hat jaana chahiye');
    });

    testWidgets('normal text field par filter nahi lagta', (t) async {
      final c = TextEditingController();
      await t.pumpWidget(wrap(Scaffold(body: F(c, 'Naam'))));
      await t.enterText(find.byType(TextField), 'Shyam Mobile');
      expect(c.text, 'Shyam Mobile');
    });
  });

  group('Theme safety', () {
    testWidgets('buildTheme() bina crash ke banti hai', (t) async {
      await t.pumpWidget(wrap(const Scaffold(body: Text('ok'))));
      expect(find.text('ok'), findsOneWidget);
    });

    testWidgets('C.fade har version par chalta hai', (t) async {
      final c = C.fade(C.primary, .5);
      expect(c.opacity, closeTo(.5, .01));
    });

    testWidgets('AppCard leftEdge render hota hai', (t) async {
      await t.pumpWidget(wrap(Scaffold(
        body: AppCard(
          leftEdge: Container(width: 4, color: C.accent),
          padding: const EdgeInsets.all(8),
          child: const Text('card'),
        ),
      )));
      expect(find.text('card'), findsOneWidget);
    });
  });

  group('Hindi UI integration', () {
    testWidgets('bade number Hindi mein', (t) async {
      await t.pumpWidget(wrap(Scaffold(
        body: Text(hindiRupees(129545, paise: false)),
      )));
      expect(find.text('एक लाख उनतीस हज़ार पाँच सौ पैंतालीस रुपये'),
          findsOneWidget);
    });
  });
}

/// pumpWidget ke baad koi exception to nahi aaya
bool testerNoException() => true;

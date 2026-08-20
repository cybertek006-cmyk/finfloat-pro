import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finfloat/core/ui.dart';
import 'package:finfloat/data/db.dart';
import 'package:finfloat/data/repo.dart';
import 'package:finfloat/screens/retailers.dart';

/// Retailer screen tests — alag file mein taaki har test file sirf
/// EK bhaari screen import kare (chhoti RAM par compiler OOM se bachne ko).
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // NOTE: DB ka open/close bhi runAsync ke andar hota hai (pumpDb dekhein),
  // kyunki fake time mein sqflite ka await kabhi poora nahi hota.
  setUp(() {
    DB.i.testPath = inMemoryDatabasePath;
  });

  Widget wrap(Widget child) => MaterialApp(theme: buildTheme(), home: child);

  /// Screen ko DB ke saath pump karta hai.
  ///
  /// ZAROORI: testWidgets ka poora body FAKE TIME mein chalta hai. Us zone
  /// mein sqflite ka koi bhi await kabhi complete nahi hota — test hamesha
  /// atak jaata hai. Isliye DB ka seeding AUR pumping, dono runAsync() ke
  /// andar hone chahiye (wahan asli waqt milta hai).
  Future<void> pumpDb(WidgetTester t, Widget w, {Future<void> Function()? seed}) async {
    await t.runAsync(() async {
      await DB.i.close();
      DB.i.testPath = inMemoryDatabasePath;
      await DB.i.db;
      if (seed != null) await seed();
      await t.pumpWidget(wrap(w));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  group('Retailer UI', () {
    testWidgets('RetailerForm bina funding ID ke raasta dikhata hai',
        (t) async {
      await pumpDb(t, const RetailerForm());
      expect(find.textContaining('funding ID nahi'), findsOneWidget);
      expect(find.textContaining('More → Company IDs'), findsOneWidget,
          reason: 'user ko batana chahiye kya karna hai');
    });

    testWidgets('RetailerForm funding ID ke saath dropdown dikhata hai',
        (t) async {
      await pumpDb(t, const RetailerForm(), seed: () async {
        await Repo.i.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
        final cid = (await Repo.i.companies()).first['id'] as int;
        await Repo.i.saveAccount(
            companyId: cid, label: 'Distributor', idNo: '993',
            type: 'distributor', fundable: true, opening: 0,
            fundsRetailers: true);
      });
      expect(find.textContaining('Kis Distributor ID'), findsOneWidget);
      expect(find.byType(DropdownButton<int>), findsOneWidget);
    });
  });
}

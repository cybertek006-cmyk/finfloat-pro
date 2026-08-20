import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finfloat/core/ui.dart';
import 'package:finfloat/data/db.dart';
import 'package:finfloat/data/repo.dart';
import 'package:finfloat/screens/more.dart';

/// Screen render tests — alag file mein isliye ki ye bhaari screens
/// (more.dart ~1500 lines) import karti hain. Ek hi file mein sab hone se
/// chhoti RAM wali machine par Dart compiler OOM ho jaata hai.
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

  group('Screens render hoti hain', () {
    testWidgets('BanksScreen khulti hai', (t) async {
      await pumpDb(t, const BanksScreen(), seed: () async {
        await Repo.i.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      });
      expect(find.text('Banks & Charges'), findsOneWidget);
      expect(find.textContaining('A2Z'), findsWidgets);
    });

    testWidgets('CompaniesScreen khulti hai', (t) async {
      await pumpDb(t, const CompaniesScreen(), seed: () async {
        await Repo.i.saveCompany(name: 'RNFi', code: 'RNFI', mode: 'auto');
      });
      expect(find.text('Companies'), findsOneWidget);
      expect(find.text('RNFi'), findsOneWidget);
    });

    testWidgets('AccountsScreen khulti hai', (t) async {
      await pumpDb(t, const AccountsScreen(), seed: () async {
        await Repo.i.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
        final cid = (await Repo.i.companies()).first['id'] as int;
        await Repo.i.saveAccount(
            companyId: cid, label: 'Distributor', idNo: '993',
            type: 'distributor', fundable: true, opening: 115308,
            fundsRetailers: true);
      });
      expect(find.text('Company IDs'), findsOneWidget);
      expect(find.textContaining('Retailer funding'), findsOneWidget,
          reason: 'funding badge dikhna chahiye');
    });

  });

}

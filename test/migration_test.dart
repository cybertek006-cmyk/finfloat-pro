import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finfloat/data/db.dart';
import 'package:finfloat/data/repo.dart';

/// ASLI file-based migration test.
///
/// Ye sabse zaroori test hai: user ke phone mein purana data pehle se hai.
/// Agar migration mein gadbad hui to uska poora hisaab ud jaayega.
/// In-memory DB se ye test nahi hota (wo har baar nayi banti hai),
/// isliye asli file banakar upgrade karte hain.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('finfloat_mig');
    dbPath = '${tmp.path}/test.db';
  });

  tearDown(() async {
    await DB.i.close();
    DB.i.testPath = null;
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// v1 jaisa purana database banata hai — jaisa user ke phone mein hoga
  Future<void> makeV1() async {
    final d = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(version: 1));
    await d.execute('''CREATE TABLE companies(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE, mode TEXT NOT NULL DEFAULT 'manual',
      phone TEXT, low_limit REAL NOT NULL DEFAULT 40000,
      active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT, company_id INTEGER NOT NULL,
      label TEXT NOT NULL, id_no TEXT, type TEXT NOT NULL DEFAULT 'retailer',
      fundable INTEGER NOT NULL DEFAULT 1, opening REAL NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE banks(
      id INTEGER PRIMARY KEY AUTOINCREMENT, company_id INTEGER NOT NULL,
      bank TEXT NOT NULL, holder TEXT, acno TEXT NOT NULL, ifsc TEXT, upi TEXT,
      chg_mode TEXT NOT NULL DEFAULT 'fixed',
      chg_rate REAL NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE cms_parties(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      mode TEXT NOT NULL DEFAULT 'percent', rate REAL NOT NULL DEFAULT 0,
      tds_pct REAL NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE cms_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT, party_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL, amount REAL NOT NULL,
      payout REAL NOT NULL DEFAULT 0, tds REAL NOT NULL DEFAULT 0,
      net REAL NOT NULL DEFAULT 0, ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE shop_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT, service_code TEXT NOT NULL,
      account_id INTEGER NOT NULL, amount REAL NOT NULL DEFAULT 0,
      txn_count INTEGER NOT NULL DEFAULT 1, payout REAL NOT NULL DEFAULT 0,
      tds REAL NOT NULL DEFAULT 0, charge REAL NOT NULL DEFAULT 0,
      net REAL NOT NULL DEFAULT 0, wallet_delta REAL NOT NULL DEFAULT 0,
      cash_delta REAL NOT NULL DEFAULT 0, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE deposits(
      id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER NOT NULL,
      bank_id INTEGER NOT NULL, amount REAL NOT NULL,
      charge REAL NOT NULL DEFAULT 0, mode TEXT NOT NULL DEFAULT 'CDM Deposit',
      utr TEXT, slip TEXT, note TEXT, date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE cash_floats(
      id INTEGER PRIMARY KEY AUTOINCREMENT, amount REAL NOT NULL,
      note TEXT, date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE retailers(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
      phone TEXT, shop TEXT, area TEXT,
      credit_limit REAL NOT NULL DEFAULT 30000,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE retailer_issues(
      id INTEGER PRIMARY KEY AUTOINCREMENT, retailer_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL, amount REAL NOT NULL, ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE retailer_recoveries(
      id INTEGER PRIMARY KEY AUTOINCREMENT, retailer_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL, amount REAL NOT NULL, method TEXT NOT NULL,
      bank_id INTEGER, utr TEXT, receipt TEXT, ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE manual_payouts(
      id INTEGER PRIMARY KEY AUTOINCREMENT, company_id INTEGER NOT NULL,
      payout REAL NOT NULL DEFAULT 0, tds REAL NOT NULL DEFAULT 0,
      extra REAL NOT NULL DEFAULT 0, net REAL NOT NULL DEFAULT 0, note TEXT,
      date TEXT NOT NULL, created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE services(
      id INTEGER PRIMARY KEY AUTOINCREMENT, code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL, direction TEXT NOT NULL,
      payout REAL NOT NULL DEFAULT 0, tds_pct REAL NOT NULL DEFAULT 0,
      charge_pct REAL NOT NULL DEFAULT 0, round_to REAL NOT NULL DEFAULT 10,
      comm_pct REAL NOT NULL DEFAULT 0, icon TEXT, color TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER)''');
    await d.execute('''CREATE TABLE day_snaps(
      id INTEGER PRIMARY KEY AUTOINCREMENT, date TEXT NOT NULL,
      kind TEXT NOT NULL, cash REAL NOT NULL DEFAULT 0, wallets TEXT,
      profit REAL NOT NULL DEFAULT 0, note TEXT,
      created_at INTEGER, updated_at INTEGER)''');

    // ---- purana asli data ----
    await d.insert('companies', {'name': 'A2Z', 'code': 'A2Z', 'mode': 'manual'});
    await d.insert('companies', {'name': 'RNFi', 'code': 'RNFI', 'mode': 'auto'});
    await d.insert('accounts', {
      'company_id': 1, 'label': 'A2Z Distributor', 'id_no': '9936404717',
      'type': 'distributor', 'fundable': 1, 'opening': 115308,
    });
    await d.insert('accounts', {
      'company_id': 2, 'label': 'RNFi Retailer', 'id_no': 'R0045736',
      'type': 'retailer', 'fundable': 1, 'opening': 129545,
    });
    await d.insert('accounts', {
      'company_id': 2, 'label': 'RNFi Distributor', 'id_no': 'D-100',
      'type': 'distributor', 'fundable': 0, 'opening': 0,
    });
    await d.insert('cms_parties',
        {'name': 'Bajaj', 'mode': 'percent', 'rate': 0.35, 'tds_pct': 5});
    await d.insert('cms_entries', {
      'party_id': 1, 'account_id': 2, 'amount': 50000, 'payout': 175,
      'tds': 8.75, 'net': 166.25, 'date': '2026-01-10', 'time': '10:00',
    });
    await d.insert('deposits', {
      'account_id': 2, 'bank_id': 1, 'amount': 20000, 'charge': 12,
      'mode': 'CDM Deposit', 'date': '2026-01-10', 'time': '11:00',
    });
    await d.insert('retailers', {'name': 'Shyam Mobile Shop', 'credit_limit': 30000});
    await d.insert('retailers', {'name': 'Verma Store', 'credit_limit': 25000});
    // Shyam ne A2Z Distributor (account 1) se 3 baar fund liya
    for (var i = 0; i < 3; i++) {
      await d.insert('retailer_issues', {
        'retailer_id': 1, 'account_id': 1, 'amount': 10000,
        'date': '2026-01-1$i', 'time': '09:00',
      });
    }
    await d.insert('retailer_recoveries', {
      'retailer_id': 1, 'account_id': 1, 'amount': 10000,
      'method': 'portal_reverse', 'date': '2026-01-10', 'time': '18:00',
    });
    await d.close();
  }

  test('v1 → v3: schema upgrade hoti hai, data bacha rehta hai', () async {
    await makeV1();

    // Ab asli app kholo — migration chalegi
    await DB.i.close();
    DB.i.testPath = dbPath;
    final d = await DB.i.db;

    expect(await d.getVersion(), 3, reason: 'version 3 par pahunchna chahiye');

    // naye columns
    final acc = (await d.rawQuery('PRAGMA table_info(accounts)'))
        .map((r) => '${r['name']}').toSet();
    expect(acc.contains('funds_retailers'), isTrue);
    final ret = (await d.rawQuery('PRAGMA table_info(retailers)'))
        .map((r) => '${r['name']}').toSet();
    expect(ret.contains('account_id'), isTrue);
    final dep = (await d.rawQuery('PRAGMA table_info(deposits)'))
        .map((r) => '${r['name']}').toSet();
    expect(dep.contains('cash_source'), isTrue);

    // nayi table
    final tables = (await d.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table'"))
        .map((r) => '${r['name']}').toSet();
    expect(tables.contains('cash_transfers'), isTrue);

    // ---- PURANA DATA SAFE? ----
    expect((await d.query('companies')).length, 2);
    expect((await d.query('accounts')).length, 3);
    expect((await d.query('cms_entries')).length, 1);
    expect((await d.query('retailer_issues')).length, 3);
    expect((await d.query('retailers')).length, 2);
    final cms = (await d.query('cms_entries')).first;
    expect(cms['net'], 166.25, reason: 'purana CMS net nahi badalna chahiye');
  });

  test('migration smart defaults: purani funding ID auto-detect', () async {
    await makeV1();
    await DB.i.close();
    DB.i.testPath = dbPath;
    final d = await DB.i.db;

    // A2Z Distributor (id 1) se pehle issues hue the -> funding ON hona chahiye
    final a2z = (await d.query('accounts', where: 'id = 1')).first;
    expect(a2z['funds_retailers'], 1,
        reason: 'jis ID se fund gaya wo funding ID honi chahiye');

    // RNFi Distributor (id 3) se kabhi fund nahi gaya -> OFF
    final rnfi = (await d.query('accounts', where: 'id = 3')).first;
    expect(rnfi['funds_retailers'], 0);

    // Shyam apne aap A2Z se map ho jaana chahiye
    final shyam = (await d.query('retailers', where: 'id = 1')).first;
    expect(shyam['account_id'], 1,
        reason: 'retailer apni sabse zyada use hui ID se map ho');

    // Verma ka koi issue nahi tha -> null rahega (user baad mein chunega)
    final verma = (await d.query('retailers', where: 'id = 2')).first;
    expect(verma['account_id'], isNull);
  });

  test('migration ke baad hisaab sahi calculate hota hai', () async {
    await makeV1();
    await DB.i.close();
    DB.i.testPath = dbPath;
    await DB.i.db;

    final repo = Repo.i;
    // A2Z: opening 115308, 3 issues × 10000 = −30000, 1 recovery +10000
    expect(await repo.wallet(1), 115308 - 30000 + 10000);
    // Shyam: 30000 diya, 10000 wapas -> 20000 baaki
    expect(await repo.retailerDue(1), 20000);
    // purane deposits default 'counter' maane jaate hain
    expect(await repo.myCash(), 50000, reason: 'CMS ka cash mere paas');
    expect(await repo.counterCash(), -20000,
        reason: 'purana deposit counter se gaya maana jaayega');

    // funding list mein sirf A2Z
    final f = await repo.fundingAccounts();
    expect(f.length, 1);
    expect(f.first['id'], 1);
  });

  test('dobara kholne par migration phir se nahi chalti', () async {
    await makeV1();
    await DB.i.close();
    DB.i.testPath = dbPath;
    await DB.i.db;
    await DB.i.close();

    // second open
    final d = await DB.i.db;
    expect(await d.getVersion(), 3);
    expect((await d.query('retailer_issues')).length, 3,
        reason: 'data duplicate nahi hona chahiye');
  });

  test('v2 → v3 bhi chalti hai', () async {
    await makeV1();
    // pehle v2 tak le jao
    var d = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(version: 2, onUpgrade: (db, f, t) async {
      await db.execute('''CREATE TABLE IF NOT EXISTS cash_transfers(
        id INTEGER PRIMARY KEY AUTOINCREMENT, from_box TEXT NOT NULL,
        to_box TEXT NOT NULL, amount REAL NOT NULL, note TEXT,
        date TEXT NOT NULL, time TEXT,
        created_at INTEGER, updated_at INTEGER)''');
      await db.execute(
          "ALTER TABLE deposits ADD COLUMN cash_source TEXT NOT NULL DEFAULT 'counter'");
    }));
    await d.close();

    await DB.i.close();
    DB.i.testPath = dbPath;
    d = await DB.i.db;
    expect(await d.getVersion(), 3);
    final acc = (await d.rawQuery('PRAGMA table_info(accounts)'))
        .map((r) => '${r['name']}').toSet();
    expect(acc.contains('funds_retailers'), isTrue);
    expect((await d.query('accounts')).length, 3, reason: 'data safe');
  });
}

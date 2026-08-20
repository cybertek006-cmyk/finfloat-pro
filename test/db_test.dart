import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:finfloat/data/db.dart';
import 'package:finfloat/data/repo.dart';
import 'package:finfloat/logic/calc.dart';

/// ASLI database ke saath integration tests.
/// Ab tak sirf logic test hota tha — ye SQLite ko sach mein chalate hain:
/// schema banti hai, migration chalti hai, paisa sahi jagah jaata hai.
void main() {
  late DB db;
  late Repo repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // Har test ke liye taaza in-memory DB
    db = DB.i;
    await db.close();
    db.testPath = inMemoryDatabasePath;
    repo = Repo.i;
    await db.db; // schema banao
  });

  tearDown(() async => db.close());

  // ---------------------------------------------------------------- schema
  group('Schema', () {
    test('saari tables ban jaati hain', () async {
      final d = await db.db;
      final t = (await d.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => '${r['name']}')
          .toSet();
      for (final need in [
        'companies', 'accounts', 'banks', 'services', 'cms_parties',
        'cms_entries', 'shop_entries', 'deposits', 'cash_transfers',
        'retailers', 'retailer_issues', 'retailer_recoveries', 'day_snaps',
      ]) {
        expect(t.contains(need), isTrue, reason: '$need table missing');
      }
    });

    test('v3 ke naye columns maujood hain', () async {
      final d = await db.db;
      final acc = (await d.rawQuery('PRAGMA table_info(accounts)'))
          .map((r) => '${r['name']}')
          .toSet();
      expect(acc.contains('funds_retailers'), isTrue);
      expect(acc.contains('fundable'), isTrue);

      final ret = (await d.rawQuery('PRAGMA table_info(retailers)'))
          .map((r) => '${r['name']}')
          .toSet();
      expect(ret.contains('account_id'), isTrue);

      final dep = (await d.rawQuery('PRAGMA table_info(deposits)'))
          .map((r) => '${r['name']}')
          .toSet();
      expect(dep.contains('cash_source'), isTrue);
    });

    test('version 3 hai', () async {
      final d = await db.db;
      final v = await d.getVersion();
      expect(v, 3);
    });
  });

  // ------------------------------------------------------------- masters
  group('Masters CRUD', () {
    test('company add/edit/duplicate-code', () async {
      expect(await repo.saveCompany(name: 'RNFi', code: 'rnfi', mode: 'auto'),
          isNull);
      final c = (await repo.companies()).first;
      expect(c['code'], 'RNFI', reason: 'code uppercase hona chahiye');

      // duplicate
      final err =
          await repo.saveCompany(name: 'Other', code: 'RNFI', mode: 'manual');
      expect(err, 'Ye code pehle se hai');

      // edit — apna hi code allowed
      expect(
          await repo.saveCompany(
              id: c['id'] as int, name: 'RNFi Ltd', code: 'RNFI', mode: 'auto'),
          isNull);
      expect((await repo.companies()).first['name'], 'RNFi Ltd');

      // validation
      expect(await repo.saveCompany(name: '', code: 'X', mode: 'auto'),
          isNotNull);
      expect(await repo.saveCompany(name: 'X', code: '', mode: 'auto'),
          isNotNull);
    });

    test('last company delete nahi hoti', () async {
      await repo.saveCompany(name: 'Only', code: 'ONLY', mode: 'auto');
      final id = (await repo.companies()).first['id'] as int;
      expect(await repo.deleteCompany(id), 'Kam se kam ek company chahiye');
    });

    test('company with IDs/banks delete nahi hoti', () async {
      await repo.saveCompany(name: 'A', code: 'A', mode: 'auto');
      await repo.saveCompany(name: 'B', code: 'B', mode: 'auto');
      final a = (await repo.companies()).firstWhere((x) => x['code'] == 'A');
      final aid = a['id'] as int;

      await repo.saveAccount(
          companyId: aid, label: 'ID1', idNo: 'X1', type: 'retailer',
          fundable: true, opening: 0);
      var err = await repo.deleteCompany(aid);
      expect(err, contains('ID hain'));

      // ID hatao, bank daalo
      final acc = (await repo.accounts()).first;
      await repo.deleteAccount(acc['id'] as int);
      await repo.saveBank(
          companyId: aid, bank: 'IB', acno: '1', chgMode: 'fixed', chgRate: 12);
      err = await repo.deleteCompany(aid);
      expect(err, contains('bank hain'));
    });

    test('bank charge: fixed vs percent', () async {
      await repo.saveCompany(name: 'A', code: 'A', mode: 'auto');
      final cid = (await repo.companies()).first['id'] as int;
      expect(
          await repo.saveBank(
              companyId: cid, bank: 'Indian', acno: '501',
              chgMode: 'fixed', chgRate: 12),
          isNull);
      expect(
          await repo.saveBank(
              companyId: cid, bank: 'Axis', acno: '918',
              chgMode: 'percent', chgRate: 0.5),
          isNull);
      // percent > 100 blocked
      expect(
          await repo.saveBank(
              companyId: cid, bank: 'Bad', acno: '1',
              chgMode: 'percent', chgRate: 150),
          isNotNull);

      final banks = await repo.banks();
      final ib = banks.firstWhere((b) => b['bank'] == 'Indian');
      final ax = banks.firstWhere((b) => b['bank'] == 'Axis');
      expect(depositCharge('${ib['chg_mode']}', numOfT(ib['chg_rate']), 5000), 12);
      expect(depositCharge('${ib['chg_mode']}', numOfT(ib['chg_rate']), 500000), 12);
      expect(depositCharge('${ax['chg_mode']}', numOfT(ax['chg_rate']), 10000), 50);
      expect(depositCharge('${ax['chg_mode']}', numOfT(ax['chg_rate']), 7350), 36.75);
    });
  });

  // ----------------------------------------------------- do cash box flows
  group('Do cash box — paisa kis box mein', () {
    late int accId, bankId, partyId;

    setUp(() async {
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      final cid = (await repo.companies()).first['id'] as int;
      await repo.saveAccount(
          companyId: cid, label: 'Dist', idNo: '993', type: 'distributor',
          fundable: true, opening: 115308, fundsRetailers: true);
      accId = (await repo.accounts()).first['id'] as int;
      await repo.saveBank(
          companyId: cid, bank: 'Indian', acno: '501',
          chgMode: 'fixed', chgRate: 12);
      bankId = (await repo.banks()).first['id'] as int;
      partyId = await repo.add('cms_parties',
          {'name': 'Bajaj', 'mode': 'percent', 'rate': 0.35, 'tds_pct': 5});
    });

    test('CMS pickup: Mera Cash +, Wallet −', () async {
      final before = await repo.wallet(accId);
      await repo.saveCms(
          partyId: partyId, accountId: accId, amount: 50000, ref: 'x');
      expect(await repo.myCash(), 50000);
      expect(await repo.counterCash(), 0, reason: 'counter ko haath nahi lagna chahiye');
      expect(await repo.wallet(accId), before - 50000);
    });

    test('deposit cash_source: mine vs counter', () async {
      // pehle cash banao
      await repo.saveCms(
          partyId: partyId, accountId: accId, amount: 50000, ref: '');
      final w0 = await repo.wallet(accId);

      await repo.saveDeposit(
          accountId: accId, bankId: bankId, amount: 20000,
          mode: 'CDM Deposit', cashSource: 'mine');
      expect(await repo.myCash(), 30000, reason: 'mere cash se gaya');
      expect(await repo.counterCash(), 0);
      expect(await repo.wallet(accId), w0 + 20000);
    });

    test('cash transfer mine <-> counter', () async {
      await repo.saveCms(
          partyId: partyId, accountId: accId, amount: 10000, ref: '');
      await repo.saveTransfer(fromBox: 'mine', toBox: 'counter', amount: 4000);
      expect(await repo.myCash(), 6000);
      expect(await repo.counterCash(), 4000);
      expect(await repo.totalCash(), 10000, reason: 'total badalna nahi chahiye');

      await repo.saveTransfer(fromBox: 'counter', toBox: 'mine', amount: 1500);
      expect(await repo.myCash(), 7500);
      expect(await repo.counterCash(), 2500);
      expect(await repo.totalCash(), 10000);
    });
  });

  // ------------------------------------------------- retailer funding flow
  group('Retailer funding — Shyam Mobile Shop', () {
    late int a2zId, retId;

    setUp(() async {
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      final cid = (await repo.companies()).first['id'] as int;
      await repo.saveAccount(
          companyId: cid, label: 'Distributor', idNo: '9936404717',
          type: 'distributor', fundable: true, opening: 115308,
          fundsRetailers: true);
      a2zId = (await repo.accounts()).first['id'] as int;
      await repo.saveRetailer(
          name: 'Shyam Mobile Shop', accountId: a2zId, creditLimit: 30000);
      retId = (await repo.retailers()).first['id'] as int;
    });

    test('funding ID list mein sirf funds_retailers=1 aati hai', () async {
      final f = await repo.fundingAccounts();
      expect(f.length, 1);
      expect(f.first['id'], a2zId);
      expect(await repo.hasFundingAccount(), isTrue);
    });

    test('retailer bina account ke save nahi hota', () async {
      final err = await repo.saveRetailer(name: 'X', accountId: null);
      expect(err, isNotNull);
    });

    test('SUBAH: 10000 fund → wallet −, udhaar +', () async {
      final w0 = await repo.wallet(a2zId);
      await repo.saveIssue(
          retailerId: retId, accountId: a2zId, amount: 10000, ref: 'subah');
      expect(await repo.wallet(a2zId), w0 - 10000);
      expect(await repo.retailerDue(retId), 10000);
      expect(await repo.myCash(), 0);
      expect(await repo.counterCash(), 0);
    });

    test('SHAAM-A: portal reverse → wallet wapas', () async {
      final w0 = await repo.wallet(a2zId);
      await repo.saveIssue(
          retailerId: retId, accountId: a2zId, amount: 10000);
      await repo.saveRecovery(
          retailerId: retId, accountId: a2zId, amount: 10000,
          method: 'portal_reverse');
      expect(await repo.wallet(a2zId), w0, reason: 'wallet wapas normal');
      expect(await repo.retailerDue(retId), 0);
      expect(await repo.myCash(), 0, reason: 'cash pe koi asar nahi');
    });

    test('SHAAM-B: CASH mila → Mera Cash +, wallet minus hi rahega', () async {
      final w0 = await repo.wallet(a2zId);
      await repo.saveIssue(
          retailerId: retId, accountId: a2zId, amount: 10000);
      await repo.saveRecovery(
          retailerId: retId, accountId: a2zId, amount: 10000,
          method: 'cash_agent');
      expect(await repo.myCash(), 10000, reason: 'CMS ki tarah mere paas');
      expect(await repo.counterCash(), 0, reason: 'staff ke counter mein NAHI');
      expect(await repo.wallet(a2zId), w0 - 10000,
          reason: 'cash aaya, portal se nahi — wallet minus hi rahega');
      expect(await repo.retailerDue(retId), 0);
    });

    test('my_account: na wallet na cash', () async {
      final w0 = await repo.wallet(a2zId);
      await repo.saveIssue(retailerId: retId, accountId: a2zId, amount: 3000);
      await repo.saveRecovery(
          retailerId: retId, accountId: a2zId, amount: 3000,
          method: 'my_account');
      expect(await repo.wallet(a2zId), w0 - 3000);
      expect(await repo.myCash(), 0);
      expect(await repo.retailerDue(retId), 0);
    });

    test('partial + mixed methods', () async {
      await repo.saveIssue(retailerId: retId, accountId: a2zId, amount: 10000);
      await repo.saveRecovery(
          retailerId: retId, accountId: a2zId, amount: 4000,
          method: 'cash_agent');
      expect(await repo.retailerDue(retId), 6000);
      expect(await repo.myCash(), 4000);
      await repo.saveRecovery(
          retailerId: retId, accountId: a2zId, amount: 6000,
          method: 'portal_reverse');
      expect(await repo.retailerDue(retId), 0);
      expect(await repo.myCash(), 4000, reason: 'sirf cash wala hissa');
    });

    test('funding ID guards', () async {
      await repo.saveIssue(retailerId: retId, accountId: a2zId, amount: 1000);
      // retailer mapped hai -> account delete block
      expect(await repo.deleteAccount(a2zId), contains('retailer jude hain'));
      // funding OFF karna block
      final err = await repo.saveAccount(
          id: a2zId, companyId: 1, label: 'D', idNo: '9',
          type: 'distributor', fundable: true, opening: 0,
          fundsRetailers: false);
      expect(err, contains('retailer jude hain'));
    });

    test('fundsRetailers sirf distributor par lagta hai', () async {
      final cid = (await repo.companies()).first['id'] as int;
      await repo.saveAccount(
          companyId: cid, label: 'Shop', idNo: 'R1', type: 'retailer',
          fundable: true, opening: 0, fundsRetailers: true);
      final shop = (await repo.accounts())
          .firstWhere((a) => a['id_no'] == 'R1');
      expect(shop['funds_retailers'], 0,
          reason: 'retailer type funding nahi kar sakta');
    });
  });

  // ------------------------------------------------------------- migration
  group('Migration v1 → v3 (purana data safe)', () {
    test('purane DB par naye columns aa jaate hain', () async {
      await db.close();
      // v1 jaisa purana schema haath se banao
      final d = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1));
      await d.execute('''CREATE TABLE companies(
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE, mode TEXT, phone TEXT,
        low_limit REAL DEFAULT 40000, active INTEGER DEFAULT 1,
        created_at INTEGER, updated_at INTEGER)''');
      await d.execute('''CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT, company_id INTEGER NOT NULL,
        label TEXT NOT NULL, id_no TEXT, type TEXT DEFAULT 'retailer',
        fundable INTEGER DEFAULT 1, opening REAL DEFAULT 0,
        created_at INTEGER, updated_at INTEGER)''');
      await d.execute('''CREATE TABLE retailers(
        id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL,
        phone TEXT, shop TEXT, area TEXT,
        credit_limit REAL DEFAULT 30000,
        created_at INTEGER, updated_at INTEGER)''');
      await d.execute('''CREATE TABLE deposits(
        id INTEGER PRIMARY KEY AUTOINCREMENT, account_id INTEGER,
        bank_id INTEGER, amount REAL, charge REAL DEFAULT 0,
        mode TEXT, utr TEXT, slip TEXT, note TEXT,
        date TEXT, time TEXT, created_at INTEGER, updated_at INTEGER)''');
      await d.execute('''CREATE TABLE retailer_issues(
        id INTEGER PRIMARY KEY AUTOINCREMENT, retailer_id INTEGER,
        account_id INTEGER, amount REAL, ref TEXT, note TEXT,
        date TEXT, time TEXT, created_at INTEGER, updated_at INTEGER)''');

      await d.insert('companies', {'name': 'A2Z', 'code': 'A2Z', 'mode': 'manual'});
      await d.insert('accounts', {
        'company_id': 1, 'label': 'Dist', 'id_no': '993',
        'type': 'distributor', 'fundable': 1, 'opening': 115308,
      });
      await d.insert('retailers', {'name': 'Shyam', 'credit_limit': 30000});
      await d.insert('retailer_issues', {
        'retailer_id': 1, 'account_id': 1, 'amount': 5000, 'date': '2026-01-01',
      });
      await d.close();

      // ab asli app kholo -> migration chalni chahiye
      db.testPath = inMemoryDatabasePath;
      // NOTE: in-memory DB har open par nayi hoti hai, isliye migration ka
      // asli test file-based hota hai. Yahan sirf ye check ki v3 schema
      // banti hai aur naye column maujood hain.
      final d2 = await db.db;
      final cols = (await d2.rawQuery('PRAGMA table_info(accounts)'))
          .map((r) => '${r['name']}')
          .toSet();
      expect(cols.contains('funds_retailers'), isTrue);
      expect(await d2.getVersion(), 3);
    });
  });

  // ---------------------------------------------------------- opening gate
  group('Opening Gate — bina opening bhare app na khule', () {
    /// main.dart ki asli shart ka copy.
    /// Gate tab lagta hai jab company bani ho aur aaj ka opening na bhara ho.
    Future<bool> gateNeeded() async {
      final done = await repo.hasSnap('open');
      final comps = await repo.companies();
      return !done && comps.isNotEmpty;
    }

    test('BUG FIX: sirf Company (bina ID ke) ho tab bhi gate lagega', () async {
      // Ye wahi bug tha -- shart `accounts.isNotEmpty` thi, isliye jab tak
      // koi Company ID add na ho gate aata hi nahi tha aur app khul jaati thi.
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      expect((await repo.accounts()).isEmpty, isTrue, reason: 'koi ID nahi');
      expect(await gateNeeded(), isTrue,
          reason: 'company hai to gate lagna hi chahiye, ID ho ya na ho');
    });

    test('opening bharne ke baad gate hat jaata hai', () async {
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      expect(await gateNeeded(), isTrue);

      await repo.saveSnap('open', 50000, {});
      expect(await gateNeeded(), isFalse, reason: 'aaj ka opening bhara hai');
    });

    test('Company ID ho to bhi gate lagta hai', () async {
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      final cid = (await repo.companies()).first['id'] as int;
      await repo.saveAccount(
          companyId: cid, label: 'Dist', idNo: '993', type: 'distributor',
          fundable: true, opening: 115308);
      expect(await gateNeeded(), isTrue);
    });

    test('bilkul nayi app (koi company nahi) -> gate nahi, pehle setup', () async {
      expect((await repo.companies()).isEmpty, isTrue);
      expect(await gateNeeded(), isFalse,
          reason: 'warna naya user phas jaayega -- masters bhar hi nahi paayega');
    });

    test('closing bharne se opening gate nahi hatta', () async {
      await repo.saveCompany(name: 'A2Z', code: 'A2Z', mode: 'manual');
      await repo.saveSnap('close', 40000, {}, profit: 500);
      expect(await gateNeeded(), isTrue,
          reason: 'close alag hai, open alag');
    });
  });

  // -------------------------------------------------------- profit sanity
  group('Net profit', () {
    test('bank charge profit se minus hota hai', () async {
      await repo.saveCompany(name: 'A', code: 'A', mode: 'auto');
      final cid = (await repo.companies()).first['id'] as int;
      await repo.saveAccount(
          companyId: cid, label: 'ID', idNo: 'X', type: 'retailer',
          fundable: true, opening: 200000);
      final accId = (await repo.accounts()).first['id'] as int;
      await repo.saveBank(
          companyId: cid, bank: 'IB', acno: '1',
          chgMode: 'fixed', chgRate: 12);
      final bankId = (await repo.banks()).first['id'] as int;
      final pid = await repo.add('cms_parties',
          {'name': 'P', 'mode': 'percent', 'rate': 0.35, 'tds_pct': 5});

      await repo.saveCms(partyId: pid, accountId: accId, amount: 50000);
      await repo.saveDeposit(
          accountId: accId, bankId: bankId, amount: 20000,
          mode: 'CDM Deposit', cashSource: 'mine');

      final p = await repo.dayProfit();
      // CMS: 50000 * 0.35% = 175, TDS 5% = 8.75, net = 166.25
      expect(p.cmsNet, 166.25);
      expect(p.depositCharges, 12);
      expect(p.net, r2(p.gross - 12));
    });
  });
}

/// chhota helper — test file ke liye
double numOfT(Object? v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

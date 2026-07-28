import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// FinFloat Pro — SQLite database (100% offline, phone ke andar).
class DB {
  DB._();
  static final DB i = DB._();

  static const String fileName = 'finfloat.db';
  static const int version = 1;

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<String> path() async => p.join(await getDatabasesPath(), fileName);

  Future<Database> _open() async {
    return openDatabase(
      await path(),
      version: version,
      onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        final b = d.batch();
        for (final s in _schema) {
          b.execute(s);
        }
        await b.commit(noResult: true);
      },
      onOpen: (d) async {
        await d.execute('PRAGMA journal_mode = WAL');
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> reopen() async {
    await close();
    await db;
  }

  // ------------------------------------------------------------- helpers
  Future<List<Map<String, Object?>>> all(String table,
          {String? where, List<Object?>? args, String? order}) async =>
      (await db).query(table, where: where, whereArgs: args, orderBy: order);

  Future<int> insert(String table, Map<String, Object?> row) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    return (await db).insert(table, {...row, 'created_at': now, 'updated_at': now});
  }

  Future<int> update(String table, int id, Map<String, Object?> row) async {
    return (await db).update(
        table, {...row, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> remove(String table, int id) async =>
      (await db).delete(table, where: 'id = ?', whereArgs: [id]);

  Future<double> sum(String sql, [List<Object?>? args]) async {
    final r = await (await db).rawQuery(sql, args);
    final v = r.first.values.first;
    return v == null ? 0 : (v as num).toDouble();
  }

  Future<int> count(String sql, [List<Object?>? args]) async {
    final r = await (await db).rawQuery(sql, args);
    final v = r.first.values.first;
    return v == null ? 0 : (v as num).toInt();
  }

  // -------------------------------------------------------------- schema
  static const List<String> _schema = [
    // Companies — auto ya manual mode
    '''CREATE TABLE companies(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      code TEXT NOT NULL UNIQUE,
      phone TEXT,
      mode TEXT NOT NULL DEFAULT 'manual',
      low_limit REAL NOT NULL DEFAULT 40000,
      active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER, updated_at INTEGER)''',

    // Company IDs — ek company mein kai ID (distributor + retailer)
    '''CREATE TABLE accounts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_id INTEGER NOT NULL,
      label TEXT NOT NULL,
      id_no TEXT NOT NULL,
      type TEXT NOT NULL DEFAULT 'retailer',
      fundable INTEGER NOT NULL DEFAULT 1,
      opening REAL NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE)''',

    // Banks — deposit charge rule yahan
    '''CREATE TABLE banks(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_id INTEGER NOT NULL,
      bank TEXT NOT NULL,
      holder TEXT,
      acno TEXT NOT NULL,
      ifsc TEXT,
      upi TEXT,
      chg_mode TEXT NOT NULL DEFAULT 'fixed',
      chg_rate REAL NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE)''',

    // Service rates — ek baar feed, phir auto
    '''CREATE TABLE services(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      code TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      direction TEXT NOT NULL,
      payout REAL NOT NULL DEFAULT 0,
      tds_pct REAL NOT NULL DEFAULT 0,
      charge_pct REAL NOT NULL DEFAULT 0,
      round_to REAL NOT NULL DEFAULT 10,
      comm_pct REAL NOT NULL DEFAULT 0,
      icon TEXT, color TEXT,
      sort_order INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER, updated_at INTEGER)''',

    // CMS parties — rate + TDS ek baar
    '''CREATE TABLE cms_parties(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      mode TEXT NOT NULL DEFAULT 'percent',
      rate REAL NOT NULL DEFAULT 0,
      tds_pct REAL NOT NULL DEFAULT 5,
      active INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER, updated_at INTEGER)''',

    // CMS pickups
    '''CREATE TABLE cms_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      party_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      payout REAL NOT NULL DEFAULT 0,
      tds REAL NOT NULL DEFAULT 0,
      net REAL NOT NULL DEFAULT 0,
      ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(party_id) REFERENCES cms_parties(id) ON DELETE RESTRICT,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''',

    // Shop entries — AEPS / UPI / transfer / recharge
    '''CREATE TABLE shop_entries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      service_code TEXT NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      txn_count INTEGER NOT NULL DEFAULT 1,
      payout REAL NOT NULL DEFAULT 0,
      tds REAL NOT NULL DEFAULT 0,
      charge REAL NOT NULL DEFAULT 0,
      net REAL NOT NULL DEFAULT 0,
      wallet_delta REAL NOT NULL DEFAULT 0,
      cash_delta REAL NOT NULL DEFAULT 0,
      note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''',

    // Manual payouts — raat ko, editable
    '''CREATE TABLE manual_payouts(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      company_id INTEGER NOT NULL,
      payout REAL NOT NULL DEFAULT 0,
      tds REAL NOT NULL DEFAULT 0,
      extra REAL NOT NULL DEFAULT 0,
      net REAL NOT NULL DEFAULT 0,
      note TEXT,
      date TEXT NOT NULL,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(company_id) REFERENCES companies(id) ON DELETE CASCADE)''',

    // Distributor auto-mode profit
    '''CREATE TABLE dist_profits(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      txn_count INTEGER NOT NULL DEFAULT 0,
      profit REAL NOT NULL DEFAULT 0,
      note TEXT,
      date TEXT NOT NULL,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''',

    // Deposits — charge yahin store hota hai
    '''CREATE TABLE deposits(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      account_id INTEGER NOT NULL,
      bank_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      charge REAL NOT NULL DEFAULT 0,
      mode TEXT NOT NULL DEFAULT 'CDM Deposit',
      utr TEXT, slip TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE,
      FOREIGN KEY(bank_id) REFERENCES banks(id) ON DELETE RESTRICT)''',

    // Counter cash float
    '''CREATE TABLE cash_floats(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      amount REAL NOT NULL,
      note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER)''',

    // Retailers (distributor side udhaar)
    '''CREATE TABLE retailers(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT, shop TEXT, area TEXT,
      credit_limit REAL NOT NULL DEFAULT 30000,
      created_at INTEGER, updated_at INTEGER)''',

    '''CREATE TABLE retailer_issues(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      retailer_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(retailer_id) REFERENCES retailers(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''',

    '''CREATE TABLE retailer_recoveries(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      retailer_id INTEGER NOT NULL,
      account_id INTEGER NOT NULL,
      amount REAL NOT NULL,
      method TEXT NOT NULL,
      bank_id INTEGER, utr TEXT, receipt TEXT, ref TEXT, note TEXT,
      date TEXT NOT NULL, time TEXT,
      created_at INTEGER, updated_at INTEGER,
      FOREIGN KEY(retailer_id) REFERENCES retailers(id) ON DELETE CASCADE,
      FOREIGN KEY(account_id) REFERENCES accounts(id) ON DELETE CASCADE)''',

    // Day open / close snapshots
    '''CREATE TABLE day_snaps(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT NOT NULL,
      kind TEXT NOT NULL,
      cash REAL NOT NULL DEFAULT 0,
      wallets TEXT,
      profit REAL NOT NULL DEFAULT 0,
      note TEXT,
      created_at INTEGER, updated_at INTEGER,
      UNIQUE(date, kind))''',

    // Indexes
    'CREATE INDEX ix_cms_date ON cms_entries(date)',
    'CREATE INDEX ix_shop_date ON shop_entries(date)',
    'CREATE INDEX ix_shop_svc ON shop_entries(service_code, date)',
    'CREATE INDEX ix_dep_date ON deposits(date)',
    'CREATE INDEX ix_mp_date ON manual_payouts(date)',
    'CREATE INDEX ix_acc_comp ON accounts(company_id)',
  ];

  /// Pehli baar app khulne par default services daalte hain (rate 0 = user feed karega)
  Future<void> seedServices() async {
    final n = await count('SELECT COUNT(*) FROM services');
    if (n > 0) return;
    const rows = [
      {'code':'aeps','name':'AEPS Cashout','direction':'cashout','icon':'👆','color':'0E8F8F','sort_order':1},
      {'code':'upi','name':'UPI Cashout','direction':'cashout','icon':'📱','color':'1B4B9B','sort_order':2},
      {'code':'upitransfer','name':'UPI Transfer','direction':'cashin','icon':'➡️','color':'6B4FBB','sort_order':3},
      {'code':'recharge','name':'Recharge (MRP)','direction':'cashin','icon':'📞','color':'C2497E','sort_order':4},
    ];
    for (final r in rows) {
      await insert('services', {...r, 'round_to': 10});
    }
  }
}

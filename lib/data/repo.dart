import 'dart:convert';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;
import '../logic/calc.dart';
import 'db.dart';

String todayStr() => DateTime.now().toIso8601String().substring(0, 10);
String nowTime() {
  final d = DateTime.now();
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// Saara data access ek jagah. UI kabhi SQL nahi likhta.
class Repo {
  Repo._();
  static final Repo i = Repo._();
  final _db = DB.i;

  // ------------------------------------------------------------- masters
  Future<List<Map<String, Object?>>> companies() =>
      _db.all('companies', order: 'name');
  Future<List<Map<String, Object?>>> accounts() async =>
      (await _db.db).rawQuery('''
        SELECT a.*, c.name AS company, c.mode AS company_mode, c.low_limit
        FROM accounts a JOIN companies c ON c.id = a.company_id
        ORDER BY c.name, a.label''');
  Future<List<Map<String, Object?>>> banks() async => (await _db.db).rawQuery('''
        SELECT b.*, c.name AS company FROM banks b
        JOIN companies c ON c.id = b.company_id ORDER BY c.name, b.bank''');
  Future<List<Map<String, Object?>>> services() =>
      _db.all('services', order: 'sort_order');
  Future<List<Map<String, Object?>>> parties() =>
      _db.all('cms_parties', order: 'name');
  Future<List<Map<String, Object?>>> retailers() =>
      _db.all('retailers', order: 'name');

  Future<Map<String, Object?>?> service(String code) async {
    final r = await _db.all('services', where: 'code = ?', args: [code]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, Object?>?> bank(int id) async {
    final r = await _db.all('banks', where: 'id = ?', args: [id]);
    return r.isEmpty ? null : r.first;
  }

  Future<Map<String, Object?>?> party(int id) async {
    final r = await _db.all('cms_parties', where: 'id = ?', args: [id]);
    return r.isEmpty ? null : r.first;
  }

  // ------------------------------------------------------------- entries
  Future<List<Map<String, Object?>>> cmsEntries({String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT e.*, p.name AS party, a.label AS account
        FROM cms_entries e
        JOIN cms_parties p ON p.id = e.party_id
        JOIN accounts a ON a.id = e.account_id
        ${date != null ? 'WHERE e.date = ?' : ''}
        ORDER BY e.date DESC, e.id DESC''', date != null ? [date] : null);

  Future<List<Map<String, Object?>>> shopEntries(
          {String? date, String? code}) async =>
      (await _db.db).rawQuery('''
        SELECT e.*, s.name AS service, s.icon, s.color, s.direction, a.label AS account
        FROM shop_entries e
        JOIN services s ON s.code = e.service_code
        JOIN accounts a ON a.id = e.account_id
        WHERE 1=1 ${date != null ? 'AND e.date = ?' : ''}
                  ${code != null ? 'AND e.service_code = ?' : ''}
        ORDER BY e.date DESC, e.id DESC''',
          [if (date != null) date, if (code != null) code]);

  Future<List<Map<String, Object?>>> deposits({String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT d.*, b.bank, b.chg_mode, b.chg_rate, a.label AS account
        FROM deposits d
        JOIN banks b ON b.id = d.bank_id
        JOIN accounts a ON a.id = d.account_id
        ${date != null ? 'WHERE d.date = ?' : ''}
        ORDER BY d.date DESC, d.id DESC''', date != null ? [date] : null);

  Future<List<Map<String, Object?>>> payouts({String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT m.*, c.name AS company FROM manual_payouts m
        JOIN companies c ON c.id = m.company_id
        ${date != null ? 'WHERE m.date = ?' : ''}
        ORDER BY m.date DESC, m.id DESC''', date != null ? [date] : null);

  Future<List<Map<String, Object?>>> distProfits({String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT d.*, a.label AS account FROM dist_profits d
        JOIN accounts a ON a.id = d.account_id
        ${date != null ? 'WHERE d.date = ?' : ''}
        ORDER BY d.date DESC''', date != null ? [date] : null);

  Future<List<Map<String, Object?>>> floats({String? date}) =>
      _db.all('cash_floats',
          where: date != null ? 'date = ?' : null,
          args: date != null ? [date] : null,
          order: 'date DESC, id DESC');

  // -------------------------------------------------------------- saves
  Future<void> saveCms({
    int? id,
    required int partyId,
    required int accountId,
    required double amount,
    String? ref,
    String? note,
    String? date,
  }) async {
    final p = await party(partyId);
    final c = cmsCalc(
      mode: '${p?['mode']}',
      rate: (p?['rate'] as num?)?.toDouble() ?? 0,
      tdsPct: (p?['tds_pct'] as num?)?.toDouble() ?? 0,
      amount: amount,
    );
    final row = {
      'party_id': partyId,
      'account_id': accountId,
      'amount': amount,
      'payout': c.payout,
      'tds': c.tds,
      'net': c.net,
      'ref': ref,
      'note': note,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('cms_entries', row)
        : await _db.update('cms_entries', id, row);
  }

  Future<void> saveShop({
    int? id,
    required String code,
    required int accountId,
    required double amount,
    required int count,
    String? note,
    String? date,
  }) async {
    final s = await service(code);
    final r = shopCalc(
      direction: '${s?['direction']}',
      payoutPerTxn: (s?['payout'] as num?)?.toDouble() ?? 0,
      tdsPct: (s?['tds_pct'] as num?)?.toDouble() ?? 0,
      chargePct: (s?['charge_pct'] as num?)?.toDouble() ?? 0,
      roundTo: (s?['round_to'] as num?)?.toDouble() ?? 10,
      commPct: (s?['comm_pct'] as num?)?.toDouble() ?? 0,
      amount: amount,
      count: count,
    );
    final row = {
      'service_code': code,
      'account_id': accountId,
      'amount': amount,
      'txn_count': count,
      'payout': r.payout,
      'tds': r.tds,
      'charge': r.charge,
      'net': r.net,
      'wallet_delta': r.walletDelta,
      'cash_delta': r.cashDelta,
      'note': note,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('shop_entries', row)
        : await _db.update('shop_entries', id, row);
  }

  Future<void> saveDeposit({
    int? id,
    required int accountId,
    required int bankId,
    required double amount,
    required String mode,
    String? utr,
    String? slip,
    String? date,
  }) async {
    final b = await bank(bankId);
    final charge = depositCharge('${b?['chg_mode']}',
        (b?['chg_rate'] as num?)?.toDouble() ?? 0, amount);
    final row = {
      'account_id': accountId,
      'bank_id': bankId,
      'amount': amount,
      'charge': charge,
      'mode': mode,
      'utr': utr,
      'slip': slip,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('deposits', row)
        : await _db.update('deposits', id, row);
  }

  Future<void> savePayout({
    int? id,
    required int companyId,
    required double payout,
    required double tds,
    required double extra,
    String? note,
    String? date,
  }) async {
    final row = {
      'company_id': companyId,
      'payout': payout,
      'tds': tds,
      'extra': extra,
      'net': manualNet(payout: payout, tds: tds, extra: extra),
      'note': note,
      'date': date ?? todayStr(),
    };
    id == null
        ? await _db.insert('manual_payouts', row)
        : await _db.update('manual_payouts', id, row);
  }

  // ------------------------------------------------------------ balances
  /// Ek company ID ka wallet.
  Future<double> wallet(int accountId) async {
    final a = await _db.all('accounts', where: 'id = ?', args: [accountId]);
    if (a.isEmpty) return 0;
    var v = (a.first['opening'] as num).toDouble();
    v += await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM deposits WHERE account_id=?', [accountId]);
    v -= await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM cms_entries WHERE account_id=?', [accountId]);
    v += await _db.sum(
        'SELECT COALESCE(SUM(wallet_delta),0) FROM shop_entries WHERE account_id=?', [accountId]);
    v -= await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM retailer_issues WHERE account_id=?', [accountId]);
    v += await _db.sum('''SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries
        WHERE account_id=? AND method IN ('portal_reverse','company_bank')''', [accountId]);
    return r2(v);
  }

  Future<double> totalWallet() async {
    final accs = await _db.all('accounts');
    var t = 0.0;
    for (final a in accs) {
      t += await wallet(a['id'] as int);
    }
    return r2(t);
  }

  /// Counter cash in hand.
  Future<double> counterCash() async {
    var v = await _db.sum('SELECT COALESCE(SUM(amount),0) FROM cash_floats');
    v += await _db.sum('SELECT COALESCE(SUM(amount),0) FROM cms_entries');
    v += await _db.sum('SELECT COALESCE(SUM(cash_delta),0) FROM shop_entries');
    v -= await _db.sum('SELECT COALESCE(SUM(amount),0) FROM deposits');
    v += await _db.sum('''SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries
        WHERE method='cash_agent' ''');
    return r2(v);
  }

  Future<double> retailerDue(int rid) async {
    final i = await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM retailer_issues WHERE retailer_id=?', [rid]);
    final r = await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries WHERE retailer_id=?', [rid]);
    return r2(i - r);
  }

  Future<double> totalDue() async {
    final rs = await retailers();
    var t = 0.0;
    for (final r in rs) {
      t += await retailerDue(r['id'] as int);
    }
    return r2(t);
  }

  // -------------------------------------------------------------- profit
  Future<DayProfit> dayProfit([String? date]) async {
    final d = date ?? todayStr();
    final w = date == null ? '' : 'WHERE date = ?';
    final a = date == null ? null : [d];
    return DayProfit(
      cmsNet: await _db.sum('SELECT COALESCE(SUM(net),0) FROM cms_entries $w', a),
      shopNet: await _db.sum('SELECT COALESCE(SUM(net),0) FROM shop_entries $w', a),
      manualNet: await _db.sum('SELECT COALESCE(SUM(net),0) FROM manual_payouts $w', a),
      distProfit: await _db.sum('SELECT COALESCE(SUM(profit),0) FROM dist_profits $w', a),
      depositCharges: await _db.sum('SELECT COALESCE(SUM(charge),0) FROM deposits $w', a),
    );
  }

  Future<double> totalTds([String? date]) async {
    final w = date == null ? '' : 'WHERE date = ?';
    final a = date == null ? null : [date];
    return r2(
        await _db.sum('SELECT COALESCE(SUM(tds),0) FROM cms_entries $w', a) +
        await _db.sum('SELECT COALESCE(SUM(tds),0) FROM shop_entries $w', a) +
        await _db.sum('SELECT COALESCE(SUM(tds),0) FROM manual_payouts $w', a));
  }

  Future<Map<String, double>> serviceTotals(String code, [String? date]) async {
    final w = date == null ? 'WHERE service_code=?' : 'WHERE service_code=? AND date=?';
    final a = date == null ? [code] : [code, date];
    return {
      'vol': await _db.sum('SELECT COALESCE(SUM(amount),0) FROM shop_entries $w', a),
      'net': await _db.sum('SELECT COALESCE(SUM(net),0) FROM shop_entries $w', a),
      'payout': await _db.sum('SELECT COALESCE(SUM(payout),0) FROM shop_entries $w', a),
      'charge': await _db.sum('SELECT COALESCE(SUM(charge),0) FROM shop_entries $w', a),
      'tds': await _db.sum('SELECT COALESCE(SUM(tds),0) FROM shop_entries $w', a),
      'cnt': (await _db.count('SELECT COALESCE(SUM(txn_count),0) FROM shop_entries $w', a)).toDouble(),
    };
  }

  Future<double> cmsVolume([String? date]) => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM cms_entries ${date != null ? 'WHERE date=?' : ''}',
      date != null ? [date] : null);

  Future<double> depositTotal([String? date]) => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM deposits ${date != null ? 'WHERE date=?' : ''}',
      date != null ? [date] : null);

  /// Jin manual companies ka aaj payout nahi bhara
  Future<List<Map<String, Object?>>> pendingPayouts() async =>
      (await _db.db).rawQuery('''
        SELECT * FROM companies WHERE mode='manual' AND active=1
        AND id NOT IN (SELECT company_id FROM manual_payouts WHERE date=?)''',
          [todayStr()]);

  // ----------------------------------------------------------- day snaps
  Future<void> saveSnap(String kind, double cash, Map<int, double> wallets,
      {double profit = 0}) async {
    await (await _db.db).insert(
      'day_snaps',
      {
        'date': todayStr(),
        'kind': kind,
        'cash': cash,
        'wallets': jsonEncode(wallets.map((k, v) => MapEntry('$k', v))),
        'profit': profit,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> hasSnap(String kind) async =>
      await _db.count('SELECT COUNT(*) FROM day_snaps WHERE date=? AND kind=?',
          [todayStr(), kind]) >
      0;

  Future<List<Map<String, Object?>>> snaps() =>
      _db.all('day_snaps', order: 'date DESC, kind');

  // ------------------------------------------------------------- generic
  Future<int> add(String t, Map<String, Object?> r) => _db.insert(t, r);
  Future<int> edit(String t, int id, Map<String, Object?> r) => _db.update(t, id, r);
  Future<int> del(String t, int id) => _db.remove(t, id);
}

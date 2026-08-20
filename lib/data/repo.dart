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

  // -------------------------------------------------- service management
  /// Naya service add karna. Code unique hona chahiye.
  /// Returns null = safal, warna error message.
  Future<String?> addService({
    required String code,
    required String name,
    required String direction, // cashout | cashin
    required String icon,
    required String color,
    double payout = 0,
    double tdsPct = 0,
    double chargePct = 0,
    double roundTo = 10,
    double commPct = 0,
  }) async {
    final clean = code.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (clean.isEmpty) return 'Code khaali nahi ho sakta';

    final existing = await _db.all('services', where: 'code = ?', args: [clean]);
    if (existing.isNotEmpty) return 'Ye code pehle se hai: $clean';

    // sabse aakhir mein rakho
    final maxOrder = await _db.count(
        'SELECT COALESCE(MAX(sort_order),0) FROM services');

    await _db.insert('services', {
      'code': clean,
      'name': name.trim(),
      'direction': direction,
      'icon': icon,
      'color': color,
      'payout': payout,
      'tds_pct': tdsPct,
      'charge_pct': chargePct,
      'round_to': roundTo <= 0 ? 1 : roundTo,
      'comm_pct': commPct,
      'sort_order': maxOrder + 1,
    });
    return null;
  }

  /// Service delete karne se pehle check — kitni entries hain
  Future<int> serviceEntryCount(String code) => _db.count(
      'SELECT COUNT(*) FROM shop_entries WHERE service_code = ?', [code]);

  /// Service delete. Agar entries hain to delete nahi hoga
  /// (warna purana hisaab toot jaayega).
  Future<String?> deleteService(int id) async {
    final rows = await _db.all('services', where: 'id = ?', args: [id]);
    if (rows.isEmpty) return 'Service nahi mili';
    final code = '${rows.first['code']}';

    final n = await serviceEntryCount(code);
    if (n > 0) {
      return 'Is service ki $n entries hain. Delete karne se purana hisaab '
          'toot jaayega. Pehle un entries ko delete karein.';
    }
    await _db.remove('services', id);
    return null;
  }

  /// Service ka order badalna (upar/neeche)
  Future<void> moveService(int id, int direction) async {
    final all = await services();
    final idx = all.indexWhere((s) => s['id'] == id);
    if (idx < 0) return;
    final swapIdx = idx + direction;
    if (swapIdx < 0 || swapIdx >= all.length) return;

    final a = all[idx], b = all[swapIdx];
    await _db.update('services', a['id'] as int,
        {'sort_order': b['sort_order']});
    await _db.update('services', b['id'] as int,
        {'sort_order': a['sort_order']});
  }

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

  /// Shop entry. Do tarike se:
  ///  A) Auto  -- amount + count do, app rate se payout/charge nikal leta hai
  ///  B) Manual-- aap khud payout, TDS, extra charge likhte ho (day-end summary)
  Future<void> saveShop({
    int? id,
    required String code,
    required int accountId,
    required double amount,
    required int count,
    String? note,
    String? date,
    // Manual day-end summary ke liye:
    bool manual = false,
    double manualPayout = 0,
    double manualTds = 0,
    double manualCharge = 0,
  }) async {
    if (manual) {
      final svc = await service(code);
      final isOut = '${svc?['direction']}' == 'cashout';
      final net = r2(manualPayout - manualTds + manualCharge);
      final row = {
        'service_code': code,
        'account_id': accountId,
        'amount': amount,
        'txn_count': count,
        'payout': manualPayout,
        'tds': manualTds,
        'charge': manualCharge,
        'net': net,
        // amount 0 ho to cash/wallet par asar nahi -- sirf kamai count hogi
        'wallet_delta': isOut ? amount : -amount,
        'cash_delta': isOut ? -amount : amount,
        'note': note,
        'date': date ?? todayStr(),
        'time': nowTime(),
      };
      id == null
          ? await _db.insert('shop_entries', row)
          : await _db.update('shop_entries', id, row);
      return;
    }

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
    String cashSource = 'counter', // mine | counter
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
      'cash_source': cashSource,
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
    var v = (a.first['opening'] as num?)?.toDouble() ?? 0;
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

  // ============================================================
  //  DO CASH BOX
  //  MERA CASH    -- CMS ka cash mere paas aata hai
  //  COUNTER CASH -- staff ke counter par shop services ka cash
  //  Wallet sirf EK hai -- dono jagah usi se kaam hota hai.
  // ============================================================

  /// Mera cash: CMS collection + counter se aaya transfer
  ///            − bank deposit (jo maine kiya) − counter ko diya float
  Future<double> myCash() async {
    var v = await _db.sum('SELECT COALESCE(SUM(amount),0) FROM cms_entries');
    v += await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_transfers WHERE to_box='mine'");
    v -= await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_transfers WHERE from_box='mine'");
    v -= await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM deposits WHERE cash_source='mine'");
    v += await _db.sum('''SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries
        WHERE method='cash_agent' ''');
    return r2(v);
  }

  /// Counter cash: staff ke paas. Shop services ka cash-in/cash-out
  ///               + mera diya float − counter se kiya deposit
  Future<double> counterCash() async {
    var v = await _db.sum('SELECT COALESCE(SUM(cash_delta),0) FROM shop_entries');
    v += await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_transfers WHERE to_box='counter'");
    v -= await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM cash_transfers WHERE from_box='counter'");
    v -= await _db.sum(
        "SELECT COALESCE(SUM(amount),0) FROM deposits WHERE cash_source='counter'");
    // purane float entries (v1 se) counter mein hi jaate the
    v += await _db.sum('SELECT COALESCE(SUM(amount),0) FROM cash_floats');
    return r2(v);
  }

  /// Dono milakar total cash
  Future<double> totalCash() async => r2(await myCash() + await counterCash());

  /// Cash transfer -- mere aur counter ke beech
  Future<void> saveTransfer({
    int? id,
    required String fromBox, // mine | counter
    required String toBox,
    required double amount,
    String? note,
    String? date,
  }) async {
    final row = {
      'from_box': fromBox,
      'to_box': toBox,
      'amount': amount,
      'note': note,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('cash_transfers', row)
        : await _db.update('cash_transfers', id, row);
  }

  Future<List<Map<String, Object?>>> transfers({String? date}) =>
      _db.all('cash_transfers',
          where: date != null ? 'date = ?' : null,
          args: date != null ? [date] : null,
          order: 'date DESC, id DESC');

  Future<double> retailerDue(int rid) async {
    final i = await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM retailer_issues WHERE retailer_id=?', [rid]);
    final r = await _db.sum(
        'SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries WHERE retailer_id=?', [rid]);
    return r2(i - r);
  }

  // -------------------------------------------------- retailer module
  /// Retailer ko diya gaya fund (issues) — company ke naam ke saath
  Future<List<Map<String, Object?>>> retailerIssues({int? rid, String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT i.*, r.name AS retailer, a.label AS account, c.name AS company
        FROM retailer_issues i
        JOIN retailers r ON r.id = i.retailer_id
        JOIN accounts a ON a.id = i.account_id
        JOIN companies c ON c.id = a.company_id
        WHERE 1=1 ${rid != null ? 'AND i.retailer_id = ?' : ''}
                  ${date != null ? 'AND i.date = ?' : ''}
        ORDER BY i.date DESC, i.id DESC''',
          [if (rid != null) rid, if (date != null) date]);

  /// Retailer se wapas aaya paisa (recoveries)
  Future<List<Map<String, Object?>>> retailerRecoveries(
          {int? rid, String? date}) async =>
      (await _db.db).rawQuery('''
        SELECT rc.*, r.name AS retailer, a.label AS account,
               c.name AS company, b.bank AS bank_name
        FROM retailer_recoveries rc
        JOIN retailers r ON r.id = rc.retailer_id
        JOIN accounts a ON a.id = rc.account_id
        JOIN companies c ON c.id = a.company_id
        LEFT JOIN banks b ON b.id = rc.bank_id
        WHERE 1=1 ${rid != null ? 'AND rc.retailer_id = ?' : ''}
                  ${date != null ? 'AND rc.date = ?' : ''}
        ORDER BY rc.date DESC, rc.id DESC''',
          [if (rid != null) rid, if (date != null) date]);

  Future<double> retailerIssued(int rid) => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM retailer_issues WHERE retailer_id=?',
      [rid]);

  Future<double> retailerRecovered(int rid) => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries WHERE retailer_id=?',
      [rid]);

  /// Recovery method wise breakup — kis tarike se kitna aaya
  Future<Map<String, double>> recoveryByMethod({int? rid}) async {
    final rows = await (await _db.db).rawQuery('''
      SELECT method, COALESCE(SUM(amount),0) AS total
      FROM retailer_recoveries
      ${rid != null ? 'WHERE retailer_id = ?' : ''}
      GROUP BY method''', [if (rid != null) rid]);
    return {
      for (final r in rows) '${r['method']}': (r['total'] as num).toDouble()
    };
  }

  /// Retailer ko fund dena — wallet se paisa nikalta hai
  Future<void> saveIssue({
    int? id,
    required int retailerId,
    required int accountId,
    required double amount,
    String? ref,
    String? note,
    String? date,
  }) async {
    final row = {
      'retailer_id': retailerId,
      'account_id': accountId,
      'amount': amount,
      'ref': ref,
      'note': note,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('retailer_issues', row)
        : await _db.update('retailer_issues', id, row);
  }

  /// Retailer se collection — 4 tarike se aa sakta hai
  Future<void> saveRecovery({
    int? id,
    required int retailerId,
    required int accountId,
    required double amount,
    required String method,
    int? bankId,
    String? utr,
    String? receipt,
    String? ref,
    String? note,
    String? date,
  }) async {
    final row = {
      'retailer_id': retailerId,
      'account_id': accountId,
      'amount': amount,
      'method': method,
      'bank_id': bankId,
      'utr': utr,
      'receipt': receipt,
      'ref': ref,
      'note': note,
      'date': date ?? todayStr(),
      'time': nowTime(),
    };
    id == null
        ? await _db.insert('retailer_recoveries', row)
        : await _db.update('retailer_recoveries', id, row);
  }

  /// Aaj kitna diya / kitna aaya
  Future<double> todayIssued() => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM retailer_issues WHERE date=?',
      [todayStr()]);

  Future<double> todayRecovered() => _db.sum(
      'SELECT COALESCE(SUM(amount),0) FROM retailer_recoveries WHERE date=?',
      [todayStr()]);

  /// Jin retailers par limit se zyada udhaar hai
  Future<List<Map<String, Object?>>> overLimitRetailers() async {
    final list = await retailers();
    final out = <Map<String, Object?>>[];
    for (final r in list) {
      final due = await retailerDue(r['id'] as int);
      if (due > (r['credit_limit'] as num).toDouble()) {
        out.add({...r, 'due': due});
      }
    }
    return out;
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

  /// Aaj ka opening bhara ya nahi -- har fundable ID ka
  /// Returns: wo IDs jinka opening baaki hai
  Future<List<Map<String, Object?>>> pendingOpening() async {
    final done = await hasSnap('open');
    if (done) return [];
    return (await accounts()).where((a) => a['fundable'] == 1).toList();
  }

  /// Aaj ka closing bhara ya nahi
  Future<bool> closingPending() async => !(await hasSnap('close'));

  /// Kal ka closing aaj ka opening ban jaata hai --
  /// pichle din ka closing snapshot le aata hai
  Future<Map<String, Object?>?> lastClosing() async {
    final rows = await (await _db.db).rawQuery('''
      SELECT * FROM day_snaps WHERE kind='close' AND date < ?
      ORDER BY date DESC LIMIT 1''', [todayStr()]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> hasSnap(String kind) async =>
      await _db.count('SELECT COUNT(*) FROM day_snaps WHERE date=? AND kind=?',
          [todayStr(), kind]) >
      0;

  Future<List<Map<String, Object?>>> snaps() =>
      _db.all('day_snaps', order: 'date DESC, kind');

  // ------------------------------------------------------ company manager
  /// Company save — code unique hona chahiye. null = safal, warna error.
  Future<String?> saveCompany({
    int? id,
    required String name,
    required String code,
    required String mode,
    String phone = '',
    double lowLimit = 40000,
  }) async {
    if (name.trim().isEmpty) return 'Company ka naam zaroori hai';
    final cd = code.trim().toUpperCase();
    if (cd.isEmpty) return 'Short code zaroori hai';
    final dup = await (await _db.db).rawQuery(
      'SELECT id FROM companies WHERE UPPER(code) = ? AND id != ?',
      [cd, id ?? -1],
    );
    if (dup.isNotEmpty) return 'Ye code pehle se hai';
    final row = {
      'name': name.trim(),
      'code': cd,
      'mode': mode,
      'phone': phone.trim(),
      'low_limit': lowLimit,
    };
    id == null ? await add('companies', row) : await edit('companies', id, row);
    return null;
  }

  /// Company delete — pehle uske IDs aur banks hatane padenge.
  /// Warna FOREIGN KEY CASCADE chup-chaap saara data uda deta.
  Future<String?> deleteCompany(int id) async {
    final d = await _db.db;
    final all = await d.rawQuery('SELECT COUNT(*) c FROM companies');
    if (_d(all.first['c']) <= 1) return 'Kam se kam ek company chahiye';
    final ids = await d.rawQuery(
        'SELECT COUNT(*) c FROM accounts WHERE company_id = ?', [id]);
    final n = _d(ids.first['c']).toInt();
    if (n > 0) return 'Is company ki $n ID hain — pehle wo delete karein';
    final bk = await d.rawQuery(
        'SELECT COUNT(*) c FROM banks WHERE company_id = ?', [id]);
    final b = _d(bk.first['c']).toInt();
    if (b > 0) return 'Is company ke $b bank hain — pehle wo delete karein';
    await del('companies', id);
    return null;
  }

  // ----------------------------------------------------- account manager
  /// Company ID save. fundable TYPE se alag hai —
  /// A2Z Distributor ID mein bhi fund hota hai.
  Future<String?> saveAccount({
    int? id,
    required int companyId,
    required String label,
    required String idNo,
    required String type,
    required bool fundable,
    required double opening,
    bool fundsRetailers = false,
  }) async {
    if (label.trim().isEmpty) return 'Label zaroori hai';
    if (idNo.trim().isEmpty) return 'ID number zaroori hai';
    if (opening < 0) return 'Opening balance minus nahi ho sakta';
    // Retailer funding sirf Distributor ID se hoti hai.
    final funds = type == 'distributor' && fundsRetailers;
    // Agar pehle funding ON thi aur ab OFF kar rahe hain, par retailers
    // mapped hain -- to rok dein, warna wo anaath ho jaayenge.
    if (id != null && !funds) {
      final r = await (await _db.db).rawQuery(
          'SELECT COUNT(*) c FROM retailers WHERE account_id = ?', [id]);
      final n = _d(r.first['c']).toInt();
      if (n > 0) {
        return 'Is ID se $n retailer jude hain — pehle unhe hataayein';
      }
    }
    final row = {
      'company_id': companyId,
      'label': label.trim(),
      'id_no': idNo.trim(),
      'type': type,
      'fundable': fundable ? 1 : 0,
      'funds_retailers': funds ? 1 : 0,
      'opening': opening,
    };
    id == null ? await add('accounts', row) : await edit('accounts', id, row);
    return null;
  }

  /// Account par kitni entries hain (deposits + cms + shop).
  Future<int> accountUsage(int id) async {
    final d = await _db.db;
    var n = 0;
    for (final t in ['deposits', 'cms_entries', 'shop_entries']) {
      try {
        final r = await d.rawQuery(
            'SELECT COUNT(*) c FROM $t WHERE account_id = ?', [id]);
        n += _d(r.first['c']).toInt();
      } catch (_) {
        // table naam alag ho to skip — guard fail-safe rehta hai
      }
    }
    return n;
  }

  /// Account delete — entries hain to rok deta hai.
  Future<String?> deleteAccount(int id) async {
    final r = await retailerCount(id);
    if (r > 0) return 'Is ID se $r retailer jude hain — pehle unhe hataayein';
    final n = await accountUsage(id);
    if (n > 0) return 'Is ID ki $n entries hain — delete nahi hoga';
    await del('accounts', id);
    return null;
  }

  // ------------------------------------------------ retailer funding IDs
  /// Wo Distributor IDs jinse retailers ko funding di jaati hai.
  /// Retailer form ke dropdown mein yahi dikhti hain.
  Future<List<Map<String, Object?>>> fundingAccounts() async =>
      (await _db.db).rawQuery('''
        SELECT a.*, c.name AS company FROM accounts a
        JOIN companies c ON c.id = a.company_id
        WHERE a.type = 'distributor' AND a.funds_retailers = 1
        ORDER BY c.name, a.label''');

  /// Kya koi bhi ID retailer funding karti hai? (module dikhana hai ya nahi)
  Future<bool> hasFundingAccount() async {
    final r = await (await _db.db).rawQuery(
        "SELECT COUNT(*) c FROM accounts WHERE type='distributor' AND funds_retailers=1");
    return _d(r.first['c']) > 0;
  }

  /// Ek funding ID ke neeche kitne retailers.
  Future<int> retailerCount(int accountId) async {
    final r = await (await _db.db).rawQuery(
        'SELECT COUNT(*) c FROM retailers WHERE account_id = ?', [accountId]);
    return _d(r.first['c']).toInt();
  }

  /// Retailer save — kis Distributor ID ke andar map hai wo zaroori hai.
  Future<String?> saveRetailer({
    int? id,
    required String name,
    required int? accountId,
    String phone = '',
    String shop = '',
    String area = '',
    double creditLimit = 30000,
  }) async {
    if (name.trim().isEmpty) return 'Retailer ka naam zaroori hai';
    if (accountId == null) {
      return 'Ye retailer kis Distributor ID mein map hai? chunein';
    }
    if (creditLimit < 0) return 'Credit limit minus nahi ho sakti';
    final row = {
      'name': name.trim(),
      'account_id': accountId,
      'phone': phone.trim(),
      'shop': shop.trim(),
      'area': area.trim(),
      'credit_limit': creditLimit,
    };
    id == null ? await add('retailers', row) : await edit('retailers', id, row);
    return null;
  }

  // --------------------------------------------------------- bank manager
  /// SQLite se aayi value ko safe double banata hai (data layer ka local helper,
  /// taaki repo ko UI file import na karni pade).
  static double _d(Object? v) =>
      v == null ? 0 : (v is num ? v.toDouble() : (double.tryParse('$v') ?? 0));

  /// Ek bank par kitni deposit entries hain + kitna charge loss hua.
  /// Delete se pehle check karne ke liye — entry hai to delete block.
  Future<Map<String, double>> bankUsage(int bankId) async {
    final r = await (await _db.db).rawQuery(
      'SELECT COUNT(*) c, IFNULL(SUM(amount),0) v, IFNULL(SUM(charge),0) g '
      'FROM deposits WHERE bank_id = ?',
      [bankId],
    );
    if (r.isEmpty) return {'count': 0, 'volume': 0, 'charge': 0};
    return {
      'count': _d(r.first['c']),
      'volume': _d(r.first['v']),
      'charge': _d(r.first['g']),
    };
  }

  /// Saare banks ka usage ek hi query mein — list screen ke liye.
  Future<Map<int, Map<String, double>>> allBankUsage() async {
    final r = await (await _db.db).rawQuery(
      'SELECT bank_id, COUNT(*) c, IFNULL(SUM(amount),0) v, IFNULL(SUM(charge),0) g '
      'FROM deposits GROUP BY bank_id',
    );
    final out = <int, Map<String, double>>{};
    for (final x in r) {
      out[x['bank_id'] as int] = {
        'count': _d(x['c']),
        'volume': _d(x['v']),
        'charge': _d(x['g']),
      };
    }
    return out;
  }

  /// Bank save — validation ke saath. null = safal, warna error message.
  Future<String?> saveBank({
    int? id,
    required int companyId,
    required String bank,
    required String acno,
    String holder = '',
    String ifsc = '',
    String upi = '',
    required String chgMode,
    required double chgRate,
  }) async {
    if (bank.trim().isEmpty) return 'Bank ka naam zaroori hai';
    if (acno.trim().isEmpty) return 'Account number zaroori hai';
    if (chgRate < 0) return 'Charge minus nahi ho sakta';
    if (chgMode == 'percent' && chgRate > 100) return 'Percent 100 se zyada nahi';
    final row = {
      'company_id': companyId,
      'bank': bank.trim(),
      'holder': holder.trim(),
      'acno': acno.trim(),
      'ifsc': ifsc.trim().toUpperCase(),
      'upi': upi.trim(),
      'chg_mode': chgMode,
      'chg_rate': chgRate,
    };
    id == null ? await add('banks', row) : await edit('banks', id, row);
    return null;
  }

  /// Bank delete — entry hai to rok deta hai. null = delete ho gaya.
  Future<String?> deleteBank(int id) async {
    final u = await bankUsage(id);
    final c = (u['count'] ?? 0).toInt();
    if (c > 0) return 'Is bank ki $c deposit entries hain — delete nahi hoga';
    await del('banks', id);
    return null;
  }

  // ------------------------------------------------------------- generic
  Future<int> add(String t, Map<String, Object?> r) => _db.insert(t, r);
  Future<int> edit(String t, int id, Map<String, Object?> r) => _db.update(t, id, r);
  Future<int> del(String t, int id) => _db.remove(t, id);
}

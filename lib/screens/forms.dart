import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';

/// ---------------------------------------------------------------- CMS
class CmsForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const CmsForm({super.key, this.edit});
  @override
  State<CmsForm> createState() => _CmsFormState();
}

class _CmsFormState extends State<CmsForm> {
  final _amt = TextEditingController();
  final _ref = TextEditingController();
  int? _party, _acc;
  List<Map<String, Object?>> _parties = [], _accs = [];
  CmsResult _calc = const CmsResult(0, 0, 0);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _amt.text = '${e['amount']}';
      _ref.text = '${e['ref'] ?? ''}';
      _party = e['party_id'] as int?;
      _acc = e['account_id'] as int?;
    }
    _load();
  }

  Future<void> _load() async {
    _parties = await Repo.i.parties();
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
    _party ??= _parties.isNotEmpty ? _parties.first['id'] as int : null;
    _acc ??= _accs.isNotEmpty ? _accs.first['id'] as int : null;
    if (mounted) setState(() {});
    _recalc();
  }

  void _recalc() {
    final p = _parties.where((x) => x['id'] == _party).firstOrNull;
    if (p == null) return;
    setState(() {
      _calc = cmsCalc(
        mode: '${p['mode']}',
        rate: numOf(p['rate']),
        tdsPct: numOf(p['tds_pct']),
        amount: parseD(_amt),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _parties.where((x) => x['id'] == _party).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(widget.edit == null ? 'CMS Pickup' : 'Edit CMS Pickup')),
      body: _parties.isEmpty
          ? const Empty('💵', 'Koi CMS party nahi',
              sub: 'More → CMS Parties se pehle party add karein')
          : ListView(padding: const EdgeInsets.all(14), children: [
              _dd<int>('CMS Party', _party, _parties.map((x) {
                final r = x['mode'] == 'percent' ? '${x['rate']}%' : '₹${x['rate']}';
                return DropdownMenuItem(
                    value: x['id'] as int, child: Text('${x['name']} — $r'));
              }).toList(), (v) {
                setState(() => _party = v);
                _recalc();
              }),
              _dd<int>('Company ID', _acc,
                  _accs.map((a) => DropdownMenuItem(
                      value: a['id'] as int,
                      child: Text('${a['company']} — ${a['label']}',
                          overflow: TextOverflow.ellipsis))).toList(),
                  (v) => setState(() => _acc = v)),
              F(_amt, 'Cash Collected *',
                  type: TextInputType.number, onChanged: (_) => _recalc()),
              F(_ref, 'Reference / Receipt No.'),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF9EC),
                    border: Border.all(color: const Color(0xFFF0DCB0)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row2('Saved rate',
                      p == null
                          ? '—'
                          : (p['mode'] == 'percent'
                              ? '${p['rate']}% of amount'
                              : '₹${p['rate']} fixed'),
                      bold: true),
                  Row2('Payout', money(_calc.payout)),
                  Row2('TDS ${p?['tds_pct'] ?? 0}%', '−${money(_calc.tds)}',
                      color: C.error),
                  const Divider(height: 12),
                  Row2('Net income', money(_calc.net), bold: true, color: C.accent),
                ]),
              ),
              const Note('Cash counter mein aayega, wallet se utna katega.'),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.accent),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : '💾 Save'),
              ),
            ]),
    );
  }

  Future<void> _save() async {
    if (parseD(_amt) <= 0) return toast(context, 'Amount daalein', bg: C.error);
    if (_party == null || _acc == null) {
      return toast(context, 'Party aur ID chunein', bg: C.error);
    }
    setState(() => _busy = true);
    await Repo.i.saveCms(
      id: widget.edit?['id'] as int?,
      partyId: _party!,
      accountId: _acc!,
      amount: parseD(_amt),
      ref: _ref.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// --------------------------------------------------------------- SHOP
class ShopForm extends StatefulWidget {
  final String code;
  final Map<String, Object?>? edit;
  const ShopForm({super.key, required this.code, this.edit});
  @override
  State<ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<ShopForm> {
  final _amt = TextEditingController();
  final _cnt = TextEditingController(text: '1');
  final _note = TextEditingController();
  late String _code = widget.code;
  int? _acc;
  List<Map<String, Object?>> _svcs = [], _accs = [];
  ShopResult? _calc;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _amt.text = '${e['amount']}';
      _cnt.text = '${e['txn_count']}';
      _note.text = '${e['note'] ?? ''}';
      _code = '${e['service_code']}';
      _acc = e['account_id'] as int?;
    }
    _load();
  }

  Future<void> _load() async {
    _svcs = await Repo.i.services();
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
    _acc ??= _accs.isNotEmpty ? _accs.first['id'] as int : null;
    if (mounted) setState(() {});
    _recalc();
  }

  Map<String, Object?>? get _svc =>
      _svcs.where((s) => s['code'] == _code).firstOrNull;

  void _recalc() {
    final s = _svc;
    if (s == null) return;
    setState(() {
      _calc = shopCalc(
        direction: '${s['direction']}',
        payoutPerTxn: numOf(s['payout']),
        tdsPct: numOf(s['tds_pct']),
        chargePct: numOf(s['charge_pct']),
        roundTo: numOf(s['round_to']),
        commPct: numOf(s['comm_pct']),
        amount: parseD(_amt),
        count: parseI(_cnt),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _svc;
    final out = s?['direction'] == 'cashout';
    final c = _calc;
    return Scaffold(
      appBar: AppBar(title: Text('${s?['name'] ?? 'Shop'} Entry')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Wrap(spacing: 7, runSpacing: 7, children: [
          for (final x in _svcs)
            ChoiceChip(
              label: Text('${x['icon']} ${'${x['name']}'.split(' ').first}',
                  style: const TextStyle(fontSize: 12)),
              selected: _code == x['code'],
              selectedColor: C.primary,
              labelStyle: TextStyle(
                  color: _code == x['code'] ? Colors.white : C.text,
                  fontWeight: FontWeight.w600),
              onSelected: (_) {
                setState(() => _code = '${x['code']}');
                _recalc();
              },
            ),
        ]),
        const SizedBox(height: 14),
        _dd<int>('Company ID', _acc,
            _accs.map((a) => DropdownMenuItem(
                value: a['id'] as int,
                child: Text('${a['company']} — ${a['label']}',
                    overflow: TextOverflow.ellipsis))).toList(),
            (v) => setState(() => _acc = v)),
        F(_amt, out ? 'Cashout Amount *' : 'Amount *',
            type: TextInputType.number, onChanged: (_) => _recalc()),
        F(_cnt, 'Kitne transactions?',
            type: TextInputType.number, onChanged: (_) => _recalc()),
        if (c != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFF9EC),
                border: Border.all(color: const Color(0xFFF0DCB0)),
                borderRadius: BorderRadius.circular(10)),
            child: Column(children: [
              if (out) ...[
                Row2('Company payout (₹${s?['payout']} × txn)', money(c.payout)),
                Row2('Customer charge ${s?['charge_pct']}%', money(c.charge),
                    color: C.accent),
                Row2('TDS ${s?['tds_pct']}%', '−${money(c.tds)}', color: C.error),
              ] else if (numOf(s?['comm_pct']) > 0)
                Row2('Commission ${s?['comm_pct']}%', money(c.payout))
              else
                Row2('Charge ${s?['charge_pct']}% (round ₹${s?['round_to']})',
                    money(c.charge),
                    color: C.accent),
              const Divider(height: 12),
              Row2('Net income', money(c.net), bold: true, color: C.accent),
            ]),
          ),
        Note(out
            ? 'Customer ko cash diya — counter cash ghatega, wallet badhega.'
            : 'Customer se cash liya — counter cash badhega, wallet ghatega.'),
        F(_note, 'Customer / Note'),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.teal),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Save'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (parseD(_amt) <= 0) return toast(context, 'Amount daalein', bg: C.error);
    if (_acc == null) return toast(context, 'Company ID chunein', bg: C.error);

    final cash = await Repo.i.counterCash();
    final c = _calc;
    if (c != null && c.cashDelta < 0 && c.cashDelta.abs() > cash && mounted) {
      final go = await confirm(context, 'Cash kam hai',
          'Counter mein sirf ${money(cash)} hai. Phir bhi entry karein?',
          ok: 'Haan');
      if (!go) return;
    }
    setState(() => _busy = true);
    await Repo.i.saveShop(
      id: widget.edit?['id'] as int?,
      code: _code,
      accountId: _acc!,
      amount: parseD(_amt),
      count: parseI(_cnt),
      note: _note.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// ------------------------------------------------------------ DEPOSIT
class DepositForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const DepositForm({super.key, this.edit});
  @override
  State<DepositForm> createState() => _DepositFormState();
}

class _DepositFormState extends State<DepositForm> {
  final _amt = TextEditingController();
  final _utr = TextEditingController();
  int? _acc, _bank;
  String _mode = 'CDM Deposit';
  List<Map<String, Object?>> _accs = [], _banks = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _amt.text = '${e['amount']}';
      _utr.text = '${e['utr'] ?? ''}';
      _acc = e['account_id'] as int?;
      _bank = e['bank_id'] as int?;
      _mode = '${e['mode']}';
    }
    _load();
  }

  Future<void> _load() async {
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
    _banks = await Repo.i.banks();
    _acc ??= _accs.isNotEmpty ? _accs.first['id'] as int : null;
    _bank ??= _banks.isNotEmpty ? _banks.first['id'] as int : null;
    if (mounted) setState(() {});
  }

  Map<String, Object?>? get _b => _banks.where((x) => x['id'] == _bank).firstOrNull;

  double get _charge {
    final b = _b;
    if (b == null) return 0;
    return depositCharge(
        '${b['chg_mode']}', numOf(b['chg_rate']), parseD(_amt));
  }

  String get _rule {
    final b = _b;
    if (b == null) return '';
    final r = numOf(b['chg_rate']);
    if (r <= 0) return 'No charge';
    return b['chg_mode'] == 'percent' ? '$r% of amount' : '₹$r per transaction';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null ? 'Fund Deposit' : 'Edit Deposit')),
      body: _banks.isEmpty
          ? const Empty('🏦', 'Koi bank nahi',
              sub: 'More → Banks se pehle bank add karein')
          : ListView(padding: const EdgeInsets.all(14), children: [
              _dd<int>('Company ID', _acc,
                  _accs.map((a) => DropdownMenuItem(
                      value: a['id'] as int,
                      child: Text('${a['company']} — ${a['label']}',
                          overflow: TextOverflow.ellipsis))).toList(),
                  (v) => setState(() => _acc = v)),
              const Text('Deposit Mode',
                  style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 7, children: [
                for (final m in ['CDM Deposit', 'Counter Deposit'])
                  ChoiceChip(
                    label: Text(m, style: const TextStyle(fontSize: 12)),
                    selected: _mode == m,
                    selectedColor: C.primary,
                    labelStyle: TextStyle(
                        color: _mode == m ? Colors.white : C.text,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _mode = m),
                  ),
              ]),
              const SizedBox(height: 14),
              _dd<int>('Bank (charge lagega)', _bank,
                  _banks.map((b) {
                    final r = numOf(b['chg_rate']);
                    final tag = r <= 0
                        ? 'free'
                        : (b['chg_mode'] == 'percent' ? '$r%' : '₹$r');
                    return DropdownMenuItem(
                        value: b['id'] as int,
                        child: Text('${b['bank']} ($tag)',
                            overflow: TextOverflow.ellipsis));
                  }).toList(),
                  (v) => setState(() => _bank = v)),
              F(_amt, 'Amount *',
                  type: TextInputType.number, onChanged: (_) => setState(() {})),
              F(_utr, 'UTR / Slip No.'),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: _charge > 0 ? const Color(0xFFFDF0F0) : const Color(0xFFF0F7F4),
                    border: Border.all(
                        color: _charge > 0 ? const Color(0xFFF0C0C0) : const Color(0xFFBFE3D3)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row2('Deposit amount', money(parseD(_amt)), bold: true),
                  Row2('Bank charge — $_rule', '−${money(_charge)}', color: C.error),
                  const Divider(height: 12),
                  Row2('Wallet mein jaayega', money(parseD(_amt)),
                      bold: true, color: C.accent),
                ]),
              ),
              const Note('Bank charge aapka loss hai — net profit se minus hoga.'),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : '💾 Save'),
              ),
            ]),
    );
  }

  Future<void> _save() async {
    if (parseD(_amt) <= 0) return toast(context, 'Amount daalein', bg: C.error);
    if (_acc == null || _bank == null) {
      return toast(context, 'ID aur bank chunein', bg: C.error);
    }
    setState(() => _busy = true);
    await Repo.i.saveDeposit(
      id: widget.edit?['id'] as int?,
      accountId: _acc!,
      bankId: _bank!,
      amount: parseD(_amt),
      mode: _mode,
      utr: _utr.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// ------------------------------------------------------ MANUAL PAYOUT
class PayoutForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const PayoutForm({super.key, this.edit});
  @override
  State<PayoutForm> createState() => _PayoutFormState();
}

class _PayoutFormState extends State<PayoutForm> {
  final _payout = TextEditingController();
  final _tds = TextEditingController();
  final _extra = TextEditingController();
  final _note = TextEditingController();
  int? _cid;
  String _date = todayStr();
  List<Map<String, Object?>> _comps = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _payout.text = '${e['payout']}';
      _tds.text = '${e['tds']}';
      _extra.text = '${e['extra']}';
      _note.text = '${e['note'] ?? ''}';
      _cid = e['company_id'] as int?;
      _date = '${e['date']}';
    }
    _load();
  }

  Future<void> _load() async {
    final all = await Repo.i.companies();
    _comps = all.where((c) => c['mode'] == 'manual').toList();
    if (_comps.isEmpty) _comps = all;
    _cid ??= _comps.isNotEmpty ? _comps.first['id'] as int : null;
    if (mounted) setState(() {});
  }

  double get _net =>
      manualNet(payout: parseD(_payout), tds: parseD(_tds), extra: parseD(_extra));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null ? 'Manual Payout' : 'Edit Payout')),
      body: _comps.isEmpty
          ? const Empty('✋', 'Koi company nahi')
          : ListView(padding: const EdgeInsets.all(14), children: [
              _dd<int>('Company', _cid,
                  _comps.map((c) => DropdownMenuItem(
                      value: c['id'] as int, child: Text('${c['name']}'))).toList(),
                  (v) => setState(() => _cid = v)),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                      context: context,
                      initialDate: DateTime.parse(_date),
                      firstDate: DateTime(2023),
                      lastDate: DateTime.now());
                  if (d != null) {
                    setState(() => _date = d.toIso8601String().substring(0, 10));
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Date'),
                  child: Text(_date, style: const TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(height: 12),
              F(_payout, 'Company Payout *',
                  type: TextInputType.number, onChanged: (_) => setState(() {})),
              F(_tds, 'TDS kata',
                  type: TextInputType.number, onChanged: (_) => setState(() {})),
              F(_extra, 'Extra income (upar se liya)',
                  type: TextInputType.number, onChanged: (_) => setState(() {})),
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF9EC),
                    border: Border.all(color: const Color(0xFFF0DCB0)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  Row2('Payout', money(parseD(_payout))),
                  Row2('+ Extra income', money(parseD(_extra)), color: C.accent),
                  Row2('− TDS', '−${money(parseD(_tds))}', color: C.error),
                  const Divider(height: 12),
                  Row2('Net', money(_net), bold: true, color: C.accent),
                ]),
              ),
              F(_note, 'Remarks'),
              const Note('Galat feed ho gaya? Payout tab se ⋮ dabakar kabhi bhi edit karein.'),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.pink),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : '💾 Save'),
              ),
            ]),
    );
  }

  Future<void> _save() async {
    if (parseD(_payout) <= 0 && parseD(_extra) <= 0) {
      return toast(context, 'Payout ya extra daalein', bg: C.error);
    }
    if (_cid == null) return toast(context, 'Company chunein', bg: C.error);
    setState(() => _busy = true);
    await Repo.i.savePayout(
      id: widget.edit?['id'] as int?,
      companyId: _cid!,
      payout: parseD(_payout),
      tds: parseD(_tds),
      extra: parseD(_extra),
      note: _note.text.trim(),
      date: _date,
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// --------------------------------------------------------- CASH FLOAT
class FloatForm extends StatefulWidget {
  const FloatForm({super.key});
  @override
  State<FloatForm> createState() => _FloatFormState();
}

class _FloatFormState extends State<FloatForm> {
  final _amt = TextEditingController();
  final _note = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Counter Cash Float')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          FutureBuilder<double>(
            future: Repo.i.counterCash(),
            builder: (c, s) => Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FB),
                  border: Border.all(color: const Color(0xFFC5D4EE)),
                  borderRadius: BorderRadius.circular(10)),
              child: Row2('Counter cash abhi', money(s.data ?? 0), bold: true),
            ),
          ),
          F(_amt, 'Cash diya staff ko *', type: TextInputType.number),
          F(_note, 'Remarks'),
          const Note('Subah staff ko jo cash dete hain AEPS/UPI cashout ke liye.'),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.warning),
            onPressed: _busy ? null : () async {
              if (parseD(_amt) <= 0) return toast(context, 'Amount daalein', bg: C.error);
              setState(() => _busy = true);
              await Repo.i.add('cash_floats', {
                'amount': parseD(_amt),
                'note': _note.text.trim(),
                'date': todayStr(),
                'time': nowTime(),
              });
              if (mounted) Navigator.pop(context, true);
            },
            child: Text(_busy ? 'Saving…' : '💾 Save'),
          ),
        ]),
      );
}

/// Shared dropdown helper.
/// DropdownButtonFormField use nahi karte kyunki uska 'value' parameter naye
/// Flutter mein 'initialValue' ho gaya hai. InputDecorator + DropdownButton
/// har version par same chalta hai.
Widget _dd<T>(String label, T? value, List<DropdownMenuItem<T>> items,
        void Function(T?) onChanged) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            isDense: true,
            items: items,
            onChanged: onChanged,
          ),
        ),
      ),
    );

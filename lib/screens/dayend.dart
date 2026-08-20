import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';

/// Day-End Summary — poore din ka total ek entry mein.
///
/// Aap har transaction alag se nahi likhte. Raat ko bas ye batate hain:
///   • kaunsi service, kis company se
///   • kitne transaction hue
///   • company se kitna payout mila (TDS kaatne ke baad)
///   • customer se kitna extra charge liya
///
/// Amount (volume) optional hai — na bharein to cash/wallet par asar nahi hoga,
/// sirf kamai count hogi.
class DayEndForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const DayEndForm({super.key, this.edit});
  @override
  State<DayEndForm> createState() => _DayEndFormState();
}

class _DayEndFormState extends State<DayEndForm> {
  final _count = TextEditingController();
  final _payout = TextEditingController();
  final _tds = TextEditingController();
  final _charge = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String? _code;
  int? _acc;
  String _date = todayStr();
  bool _showVolume = false;
  List<Map<String, Object?>> _svcs = [], _accs = [];
  bool _busy = false, _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _code = '${e['service_code']}';
      _acc = e['account_id'] as int?;
      _count.text = '${e['txn_count']}';
      _payout.text = '${numOf(e['payout'])}';
      _tds.text = '${numOf(e['tds'])}';
      _charge.text = '${numOf(e['charge'])}';
      _note.text = '${e['note'] ?? ''}';
      _date = '${e['date']}';
      final amt = numOf(e['amount']);
      if (amt > 0) {
        _showVolume = true;
        _amount.text = amt.toStringAsFixed(0);
      }
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [_count, _payout, _tds, _charge, _amount, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _svcs = await Repo.i.services();
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
    _code ??= _svcs.isNotEmpty ? '${_svcs.first['code']}' : null;
    _acc ??= _accs.isNotEmpty ? _accs.first['id'] as int : null;
    if (mounted) setState(() => _loading = false);
  }

  double get _net =>
      r2(parseD(_payout) - parseD(_tds) + parseD(_charge));

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Day-End Summary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_svcs.isEmpty || _accs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Day-End Summary')),
        body: Empty(_svcs.isEmpty ? '⚙️' : '🆔',
            _svcs.isEmpty ? 'Koi service nahi' : 'Koi Company ID nahi',
            sub: _svcs.isEmpty
                ? 'More → Services & Rates se add karein'
                : 'More → Company IDs se add karein'),
      );
    }

    final svc = _svcs.firstWhere((s) => s['code'] == _code,
        orElse: () => _svcs.first);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null
              ? 'Day-End Summary'
              : 'Edit Summary')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Note(
          'Poore din ka total ek saath likhein. Har transaction alag se '
          'likhne ki zaroorat nahi.',
        ),

        // Service
        const Text('Kaunsi service?',
            style: TextStyle(
                fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: _svcs
              .map((s) => ChoiceChip(
                    label: Text('${s['icon']} ${s['name']}',
                        style: const TextStyle(fontSize: 12)),
                    selected: _code == s['code'],
                    selectedColor: C.hex('${s['color']}'),
                    labelStyle: TextStyle(
                        color: _code == s['code'] ? Colors.white : C.text,
                        fontWeight: FontWeight.w600),
                    onSelected: (_) => setState(() => _code = '${s['code']}'),
                  ))
              .toList(),
        ),
        const SizedBox(height: 14),

        // Company ID
        _dd<int>('Kis company se hua?', _acc,
            _accs
                .map((a) => DropdownMenuItem(
                    value: a['id'] as int,
                    child: Text('${a['company']} — ${a['label']}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            (v) => setState(() => _acc = v)),

        // Date
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.parse(_date),
                firstDate: DateTime(2024),
                lastDate: DateTime.now());
            if (picked != null) {
              setState(() =>
                  _date = picked.toIso8601String().substring(0, 10));
            }
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Date'),
            child: Text(_date, style: const TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),

        F(_count, 'Kitne transaction hue? *', type: TextInputType.number, intOnly: true),
        F(_payout, 'Company payout mila (₹)',
            type: TextInputType.number, onChanged: (_) => setState(() {})),
        F(_tds, 'TDS kata (₹)',
            type: TextInputType.number, onChanged: (_) => setState(() {})),
        F(_charge, 'Customer se extra charge liya (₹)',
            type: TextInputType.number, onChanged: (_) => setState(() {})),

        // Volume optional
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
          decoration: BoxDecoration(
            color: _showVolume ? const Color(0xFFF0F4FB) : const Color(0xFFF7F7F7),
            border: Border.all(
                color: _showVolume ? const Color(0xFFC5D4EE) : C.divider),
            borderRadius: BorderRadius.circular(10),
          ),
          child: SwitchListTile(
            value: _showVolume,
            onChanged: (v) => setState(() {
              _showVolume = v;
              if (!v) _amount.clear();
            }),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: const Text('Total volume bhi likhna hai?',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            subtitle: Text(
              _showVolume
                  ? svc['direction'] == 'cashout' ? 'Counter cash ghatega, wallet badhega' : 'Counter cash badhega, wallet ghatega'
                  : 'Nahi bharenge to sirf kamai count hogi',
              style: const TextStyle(fontSize: 10.5),
            ),
          ),
        ),
        if (_showVolume)
          F(_amount, 'Total amount (₹)', type: TextInputType.number),

        F(_note, 'Note'),

        // Calculation preview
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9EC),
            border: Border.all(color: const Color(0xFFF0DCB0)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Row2('${parseI(_count)} transactions', '', small: true),
            Row2('Company payout', money(parseD(_payout))),
            Row2('− TDS', '−${money(parseD(_tds))}', color: C.error),
            Row2('+ Extra charge', money(parseD(_charge)), color: C.accent),
            const Divider(height: 12),
            Row2('Net kamai', money(_net), bold: true, color: C.accent),
          ]),
        ),

        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: C.hex('${svc['color']}')),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Save Summary'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    if (parseI(_count) <= 0) {
      return toast(context, 'Kitne transaction hue? likhein', bg: C.error);
    }
    if (parseD(_payout) == 0 && parseD(_charge) == 0) {
      return toast(context, 'Payout ya charge daalein', bg: C.error);
    }
    if (_code == null || _acc == null) {
      return toast(context, 'Service aur company chunein', bg: C.error);
    }
    setState(() => _busy = true);
    await Repo.i.saveShop(
      id: widget.edit?['id'] as int?,
      code: _code!,
      accountId: _acc!,
      amount: _showVolume ? parseD(_amount) : 0,
      count: parseI(_count),
      note: _note.text.trim(),
      date: _date,
      manual: true,
      manualPayout: parseD(_payout),
      manualTds: parseD(_tds),
      manualCharge: parseD(_charge),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// -------------------------------------------------------- CASH TRANSFER
/// Mere cash aur counter cash ke beech paisa
class TransferForm extends StatefulWidget {
  const TransferForm({super.key});
  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _amt = TextEditingController();
  final _note = TextEditingController();
  String _from = 'mine';
  double _myCash = 0, _ctrCash = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amt.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _myCash = await Repo.i.myCash();
    _ctrCash = await Repo.i.counterCash();
    if (mounted) setState(() {});
  }

  String get _to => _from == 'mine' ? 'counter' : 'mine';

  @override
  Widget build(BuildContext context) {
    final amt = parseD(_amt);
    final fromBal = _from == 'mine' ? _myCash : _ctrCash;
    final toBal = _from == 'mine' ? _ctrCash : _myCash;

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Transfer')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        const Note('Apne cash aur staff ke counter cash ke beech paisa.'),

        // Direction
        GestureDetector(
          onTap: () => setState(() => _from = _from == 'mine' ? 'counter' : 'mine'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: C.divider),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Expanded(
                child: Column(children: [
                  Text(_from == 'mine' ? '👤 Mera Cash' : '🏪 Counter',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(money(fromBal),
                      style: const TextStyle(fontSize: 11.5, color: C.muted)),
                ]),
              ),
              const Column(children: [
                Icon(Icons.arrow_forward, color: C.primary),
                Text('badlein',
                    style: TextStyle(fontSize: 9, color: C.muted)),
              ]),
              Expanded(
                child: Column(children: [
                  Text(_to == 'mine' ? '👤 Mera Cash' : '🏪 Counter',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(money(toBal),
                      style: const TextStyle(fontSize: 11.5, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Text('Direction badalne ke liye upar tap karein',
              style: TextStyle(fontSize: 10.5, color: C.muted)),
        ),
        const SizedBox(height: 14),

        F(_amt, 'Amount *',
            type: TextInputType.number, onChanged: (_) => setState(() {})),
        F(_note, 'Note'),

        if (amt > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: amt > fromBal
                  ? const Color(0xFFFDF0F0)
                  : const Color(0xFFF0F7F4),
              border: Border.all(
                  color: amt > fromBal
                      ? const Color(0xFFF0C0C0)
                      : const Color(0xFFBFE3D3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(children: [
              Row2(_from == 'mine' ? 'Mera cash baad mein' : 'Counter baad mein',
                  money(fromBal - amt),
                  bold: true, color: amt > fromBal ? C.error : null),
              Row2(_to == 'mine' ? 'Mera cash baad mein' : 'Counter baad mein',
                  money(toBal + amt),
                  bold: true, color: C.accent),
              if (amt > fromBal)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('⚠️ Itna cash nahi hai',
                      style: TextStyle(
                          fontSize: 11,
                          color: C.error,
                          fontWeight: FontWeight.w600)),
                ),
            ]),
          ),

        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.warning),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Transfer'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final amt = parseD(_amt);
    if (amt <= 0) return toast(context, 'Amount daalein', bg: C.error);
    final fromBal = _from == 'mine' ? _myCash : _ctrCash;
    if (amt > fromBal) {
      final go = await confirm(context, 'Cash kam hai',
          'Sirf ${money(fromBal)} hai. Phir bhi transfer karein?',
          ok: 'Haan');
      if (!go) return;
    }
    setState(() => _busy = true);
    await Repo.i.saveTransfer(
        fromBox: _from, toBox: _to, amount: amt, note: _note.text.trim());
    if (mounted) Navigator.pop(context, true);
  }
}

Widget _dd<T>(String label, T? value, List<DropdownMenuItem<T>> items,
        void Function(T?) onChanged) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
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

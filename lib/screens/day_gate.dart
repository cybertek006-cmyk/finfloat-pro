import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';

/// Opening Gate — subah app khulte hi.
/// Jab tak har company ID ka opening balance na bhar dein, app aage
/// nahi badhne deta. Isliye "Cancel" ka option nahi hai.
class OpeningGate extends StatefulWidget {
  final VoidCallback onDone;
  const OpeningGate({super.key, required this.onDone});
  @override
  State<OpeningGate> createState() => _OpeningGateState();
}

class _OpeningGateState extends State<OpeningGate> {
  final _myCash = TextEditingController();
  final _ctrCash = TextEditingController();
  final Map<int, TextEditingController> _w = {};
  List<Map<String, Object?>> _accs = [];
  final Map<String, double> _last = {};
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _myCash.dispose();
    _ctrCash.dispose();
    for (final c in _w.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();

    // Kal ka closing aaj ka opening banega
    final last = await Repo.i.lastClosing();
    if (last != null) {
      _myCash.text = numOf(last['cash']).toStringAsFixed(0);
    }

    for (final a in _accs) {
      final id = a['id'] as int;
      final v = await Repo.i.wallet(id);
      _w[id] = TextEditingController(text: v.toStringAsFixed(0));
      _last['$id'] = v;
    }
    _myCash.text = _myCash.text.isEmpty
        ? (await Repo.i.myCash()).toStringAsFixed(0)
        : _myCash.text;
    _ctrCash.text = (await Repo.i.counterCash()).toStringAsFixed(0);
    if (mounted) setState(() => _loading = false);
  }

  bool get _allFilled {
    if (_myCash.text.trim().isEmpty || _ctrCash.text.trim().isEmpty) {
      return false;
    }
    for (final c in _w.values) {
      if (c.text.trim().isEmpty) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Back button block -- gate hai, skip nahi kar sakte
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: C.primary,
        body: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('☀️', style: TextStyle(fontSize: 34)),
                          const SizedBox(height: 8),
                          const Text('Day Start',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                            'Aaj ka opening balance bharein. '
                            'Bina bhare aage nahi badh sakte.',
                            style: TextStyle(
                                color: C.fade(Colors.white, .71),
                                fontSize: 12,
                                height: 1.5),
                          ),
                        ]),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: C.surface,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const Text('💰 Cash',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          _row('👤 Mera Cash', 'CMS ka cash mere paas',
                              _myCash),
                          _row('🏪 Counter Cash', 'Staff ke paas',
                              _ctrCash),
                          const SizedBox(height: 8),
                          // Heading sirf tab jab sach mein koi ID ho --
                          // warna khaali heading ajeeb lagti hai
                          if (_accs.isNotEmpty) ...[
                            const Text('💼 Company Wallets',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 8),
                          ] else
                            const Note('Abhi koi Company ID nahi hai. '
                                'More → Company IDs se add karein — '
                                'phir yahan unka wallet balance bhi poochha jaayega.'),
                          ..._accs.map((a) {
                            final id = a['id'] as int;
                            return _row(
                              '${a['company']}',
                              '${a['label']} · pichla ${money(_last['$id'])}',
                              _w[id]!,
                            );
                          }),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor:
                                    _allFilled ? C.warning : C.muted,
                                minimumSize: const Size.fromHeight(50)),
                            onPressed: (_busy || !_allFilled) ? null : _save,
                            child: Text(
                                _busy
                                    ? 'Saving…'
                                    : (_allFilled
                                        ? '☀️ Din Shuru Karein'
                                        : 'Sab khaane bharein'),
                                style: const TextStyle(fontSize: 15)),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _row(String title, String sub, TextEditingController c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: C.muted)),
                ]),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 118,
            child: TextField(
              controller: c,
              // decimal ke saath -- Android ke plain number keypad mein
              // dot hota hi nahi, isliye numberWithOptions zaroori hai
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 11)),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ]),
      );

  Future<void> _save() async {
    setState(() => _busy = true);
    final wallets = <int, double>{};
    for (final e in _w.entries) {
      wallets[e.key] = parseD(e.value);
    }
    await Repo.i.saveSnap('open', parseD(_myCash) + parseD(_ctrCash), wallets);
    if (!mounted) return;
    widget.onDone();
  }
}

/// Closing reminder — raat 11 baje ke baad, jab tak closing na bhar dein
/// baar-baar dikhta rahega.
class ClosingReminder {
  static Timer? _timer;
  static bool _showing = false;

  /// Reminder chalu karo. Har 10 minute mein check karta hai.
  static void start(BuildContext Function() ctx) {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) async {
      await _check(ctx);
    });
    // pehla check turant
    Future.delayed(const Duration(seconds: 2), () => _check(ctx));
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _check(BuildContext Function() ctx) async {
    if (_showing) return;
    final now = DateTime.now();
    if (now.hour < 23) return; // 11 PM se pehle nahi

    final pending = await Repo.i.closingPending();
    if (!pending) return;

    final context = ctx();
    if (!context.mounted) return;

    _showing = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Row(children: [
          Text('🌙', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Expanded(
              child: Text('Day Close baaki hai',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
        ]),
        content: const Text(
          'Aaj ka closing balance abhi tak nahi bhara.\n\n'
          'Bina closing ke kal ka hisaab sahi nahi milega.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('10 min baad'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(c);
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ClosingScreen(onDone: () {})));
            },
            child: const Text('Abhi karein'),
          ),
        ],
      ),
    );
    _showing = false;
  }
}

/// Closing screen — raat ka hisaab
class ClosingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const ClosingScreen({super.key, required this.onDone});
  @override
  State<ClosingScreen> createState() => _ClosingScreenState();
}

class _ClosingScreenState extends State<ClosingScreen> {
  final _myCash = TextEditingController();
  final _ctrCash = TextEditingController();
  final Map<int, TextEditingController> _w = {};
  final Map<int, double> _expected = {};
  List<Map<String, Object?>> _accs = [];
  double _expMy = 0, _expCtr = 0;
  DayProfit _profit = const DayProfit();
  bool _loading = true, _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _myCash.dispose();
    _ctrCash.dispose();
    for (final c in _w.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    _accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
    _expMy = await Repo.i.myCash();
    _expCtr = await Repo.i.counterCash();
    _profit = await Repo.i.dayProfit(todayStr());
    for (final a in _accs) {
      final id = a['id'] as int;
      _expected[id] = await Repo.i.wallet(id);
      _w[id] = TextEditingController();
    }
    if (mounted) setState(() => _loading = false);
  }

  double _diff(TextEditingController c, double exp) =>
      c.text.trim().isEmpty ? 0 : parseD(c) - exp;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🌙 Day Close')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              const Note('Actual cash aur wallet ginkar likhein. '
                  'Difference apne aap dikhega.'),

              const Text('💰 Cash',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _row('👤 Mera Cash', _expMy, _myCash),
              _row('🏪 Counter Cash', _expCtr, _ctrCash),

              const SizedBox(height: 10),
              const Text('💼 Company Wallets',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ..._accs.map((a) {
                final id = a['id'] as int;
                return _row('${a['company']} · ${a['label']}',
                    _expected[id] ?? 0, _w[id]!);
              }),

              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(13),
                child: Column(children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Aaj ka Profit',
                        style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Row2('CMS', money(_profit.cmsNet), small: true),
                  Row2('Shop services', money(_profit.shopNet), small: true),
                  Row2('Distributor', money(_profit.distProfit), small: true),
                  Row2('Manual payouts', money(_profit.manualNet), small: true),
                  const Divider(height: 12),
                  Row2('Gross income', money(_profit.gross), bold: true),
                  Row2('− Bank charges', '−${money(_profit.depositCharges)}',
                      color: C.error),
                  const Divider(height: 12),
                  Row2('NET PROFIT', money(_profit.net),
                      bold: true, color: C.accent),
                ]),
              ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50)),
                onPressed: _busy ? null : _save,
                child: Text(_busy ? 'Saving…' : '🌙 Day Close Karein',
                    style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 20),
            ]),
    );
  }

  Widget _row(String title, double exp, TextEditingController c) {
    final d = _diff(c, exp);
    final filled = c.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text('Expected ${money(exp)}',
                      style: const TextStyle(fontSize: 10, color: C.muted)),
                ]),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 118,
            child: TextField(
              controller: c,
              keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  isDense: true,
                  hintText: exp.toStringAsFixed(0),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 11)),
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
        ]),
        if (filled)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                d.abs() < 0.01
                    ? '✓ Sahi'
                    : 'Difference ${d > 0 ? '+' : ''}${money(d)}',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: d.abs() < 0.01 ? C.accent : C.error),
              ),
            ),
          ),
      ]),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final wallets = <int, double>{};
    for (final e in _w.entries) {
      wallets[e.key] = e.value.text.trim().isEmpty
          ? (_expected[e.key] ?? 0)
          : parseD(e.value);
    }
    final my = _myCash.text.trim().isEmpty ? _expMy : parseD(_myCash);
    final ctr = _ctrCash.text.trim().isEmpty ? _expCtr : parseD(_ctrCash);
    await Repo.i.saveSnap('close', my + ctr, wallets, profit: _profit.net);
    if (!mounted) return;
    Navigator.pop(context);
    widget.onDone();
    toast(context, 'Day close · Net profit ${money(_profit.net)}');
  }
}

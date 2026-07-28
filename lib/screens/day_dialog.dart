import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';

/// Subah Day Start / Raat Day Close popup.
/// Auto mode wali company khud bhar jaati hai, manual wali aap bharte hain.
Future<void> showDayDialog(BuildContext context, String kind) async {
  final accs = (await Repo.i.accounts()).where((a) => a['fundable'] == 1).toList();
  final cash = await Repo.i.counterCash();
  final profit = await Repo.i.dayProfit(todayStr());
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DayDialog(
      kind: kind,
      accounts: accs,
      expectedCash: cash,
      profit: profit,
    ),
  );
}

class _DayDialog extends StatefulWidget {
  final String kind;
  final List<Map<String, Object?>> accounts;
  final double expectedCash;
  final DayProfit profit;
  const _DayDialog({
    required this.kind,
    required this.accounts,
    required this.expectedCash,
    required this.profit,
  });

  @override
  State<_DayDialog> createState() => _DayDialogState();
}

class _DayDialogState extends State<_DayDialog> {
  final _cash = TextEditingController();
  final Map<int, TextEditingController> _w = {};
  final Map<int, double> _expected = {};
  bool _busy = false;

  bool get isOpen => widget.kind == 'open';

  @override
  void initState() {
    super.initState();
    _cash.text = widget.expectedCash.toStringAsFixed(0);
    for (final a in widget.accounts) {
      final id = a['id'] as int;
      _w[id] = TextEditingController();
      Repo.i.wallet(id).then((v) {
        _expected[id] = v;
        if (isOpen) _w[id]!.text = v.toStringAsFixed(0);
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _cash.dispose();
    for (final c in _w.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _cashDiff => parseD(_cash) - widget.expectedCash;

  @override
  Widget build(BuildContext context) {
    final p = widget.profit;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      title: Row(children: [
        Text(isOpen ? '☀️' : '🌙', style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(isOpen ? 'Day Start' : 'Day Close',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ),
      ]),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              isOpen
                  ? 'Subah ka opening feed karein — cash in hand aur har company ka wallet.'
                  : 'Actual cash aur wallet daalein. Auto wale apne aap bhare hain.',
              style: const TextStyle(fontSize: 11.5, color: C.muted, height: 1.5),
            ),
            const SizedBox(height: 14),

            // Cash
            _row('💰 Cash in Hand', 'Expected ${money(widget.expectedCash)}', _cash,
                onChanged: () => setState(() {})),
            if (!isOpen && _cash.text.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _cashDiff.abs() < 0.01
                        ? '✓ Bilkul sahi'
                        : 'Difference ${_cashDiff > 0 ? '+' : ''}${money(_cashDiff)}',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _cashDiff.abs() < 0.01 ? C.accent : C.error),
                  ),
                ),
              ),

            // Wallets
            for (final a in widget.accounts)
              _row(
                '${a['company']}',
                'Expected ${money(_expected[a['id']] ?? 0)}',
                _w[a['id'] as int]!,
                badge: a['company_mode'] == 'auto' ? 'AUTO' : 'MANUAL',
                badgeColor: a['company_mode'] == 'auto' ? C.accent : C.pink,
              ),

            if (!isOpen) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF9EC),
                    border: Border.all(color: const Color(0xFFF0DCB0)),
                    borderRadius: BorderRadius.circular(10)),
                child: Column(children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Aaj ka Profit',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 5),
                  Row2('CMS (auto)', money(p.cmsNet), small: true),
                  Row2('Shop services (auto)', money(p.shopNet), small: true),
                  Row2('Distributor (auto)', money(p.distProfit), small: true),
                  Row2('Manual payouts', money(p.manualNet), small: true),
                  const Divider(height: 12),
                  Row2('Gross income', money(p.gross), bold: true),
                  Row2('− Bank deposit charges', '−${money(p.depositCharges)}',
                      color: C.error),
                  const Divider(height: 12),
                  Row2('NET PROFIT', money(p.net), bold: true, color: C.accent),
                ]),
              ),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Baad mein')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: isOpen ? C.warning : C.primary),
          onPressed: _busy ? null : _save,
          child: Text(isOpen ? 'Day Start' : 'Day Close'),
        ),
      ],
    );
  }

  Widget _row(String label, String sub, TextEditingController ctrl,
      {String? badge, Color? badgeColor, VoidCallback? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                Badge2(badge, badgeColor ?? C.accent),
              ],
            ]),
            Text(sub, style: const TextStyle(fontSize: 10, color: C.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 108,
          child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged?.call(),
            decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
            style: const TextStyle(fontSize: 13),
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
    await Repo.i.saveSnap(
      widget.kind,
      _cash.text.trim().isEmpty ? widget.expectedCash : parseD(_cash),
      wallets,
      profit: isOpen ? 0 : widget.profit.net,
    );
    if (!mounted) return;
    Navigator.pop(context);
    toast(
      context,
      isOpen
          ? 'Day start ho gaya'
          : 'Day close · Net profit ${money(widget.profit.net)}',
    );
  }
}

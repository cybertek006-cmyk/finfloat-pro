import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import 'forms.dart';

/// Shared: list ke items par ⋮ menu (Edit / Delete)
Future<String?> rowMenu(BuildContext c, String title,
    {bool canEdit = true}) async {
  return showModalBottomSheet<String>(
    context: c,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
    builder: (x) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: C.primary)),
          ),
        ),
        if (canEdit)
          ListTile(
            leading: const Icon(Icons.edit_outlined, size: 20),
            title: const Text('Edit', style: TextStyle(fontSize: 14)),
            onTap: () => Navigator.pop(x, 'edit'),
          ),
        ListTile(
          leading: const Icon(Icons.delete_outline, size: 20, color: C.error),
          title: const Text('Delete',
              style: TextStyle(fontSize: 14, color: C.error)),
          onTap: () => Navigator.pop(x, 'delete'),
        ),
        ListTile(
          leading: const Icon(Icons.close, size: 20, color: C.muted),
          title: const Text('Cancel',
              style: TextStyle(fontSize: 14, color: C.muted)),
          onTap: () => Navigator.pop(x),
        ),
      ]),
    ),
  );
}

/// ---------------------------------------------------------------- SHOP
class ShopTab extends StatefulWidget {
  final VoidCallback onChanged;
  const ShopTab({super.key, required this.onChanged});
  @override
  State<ShopTab> createState() => _ShopTabState();
}

class _ShopTabState extends State<ShopTab> {
  Future<Map<String, dynamic>> _load() async {
    final d = todayStr();
    final svcs = await Repo.i.services();
    final totals = <String, Map<String, double>>{};
    for (final s in svcs) {
      totals['${s['code']}'] = await Repo.i.serviceTotals('${s['code']}', d);
    }
    return {
      'svcs': svcs,
      'totals': totals,
      'entries': await Repo.i.shopEntries(date: d),
    };
  }

  void _refresh() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final svcs = (snap.data!['svcs'] as List).cast<Map<String, Object?>>();
        final totals = snap.data!['totals'] as Map<String, Map<String, double>>;
        final entries = (snap.data!['entries'] as List).cast<Map<String, Object?>>();

        return ListView(padding: const EdgeInsets.all(14), children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in svcs)
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 44) / 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: C.hex('${s['color']}'),
                        minimumSize: const Size.fromHeight(42)),
                    onPressed: () => _open(ShopForm(code: '${s['code']}')),
                    child: Text('${s['icon']} ${'${s['name']}'.split(' ').first}',
                        style: const TextStyle(fontSize: 12.5)),
                  ),
                ),
            ],
          ),
          const Sec("Aaj ka Shop Summary"),
          for (final s in svcs)
            if ((totals['${s['code']}']?['cnt'] ?? 0) > 0)
              _svcCard(s, totals['${s['code']}']!),
          Sec('Aaj ki Entries (${entries.length})'),
          if (entries.isEmpty)
            const Empty('📝', 'Aaj koi entry nahi',
                sub: 'Staff ki copy se transaction daalein')
          else
            ...entries.map((e) => Tile(
                  icon: '${e['icon']}',
                  color: C.hex('${e['color']}'),
                  title: '${e['service']}'
                      '${(e['txn_count'] as int) > 1 ? ' ×${e['txn_count']}' : ''}',
                  sub: '${e['time']}'
                      '${e['note'] != null && '${e['note']}'.isNotEmpty ? ' · ${e['note']}' : ''}\n'
                      'Payout ${moneynumOf(e['payout'])} + Chg ${moneynumOf(e['charge'])} − TDS ${moneynumOf(e['tds'])}',
                  amount: moneynumOf(e['amount']),
                  amountSub: '+${moneynumOf(e['net'])}',
                  onMenu: () async {
                    final r = await rowMenu(
                        context, '${e['service']} · ${moneynumOf(e['amount'])}');
                    if (r == 'edit' && mounted) {
                      _open(ShopForm(code: '${e['service_code']}', edit: e));
                    } else if (r == 'delete' && mounted) {
                      if (await confirm(context, 'Delete entry?',
                          'Ye entry hat jaayegi aur hisaab update ho jaayega.')) {
                        await Repo.i.del('shop_entries', e['id'] as int);
                        _refresh();
                      }
                    }
                  },
                )),
        ]);
      },
    );
  }

  Widget _svcCard(Map<String, Object?> s, Map<String, double> t) {
    final out = s['direction'] == 'cashout';
    final col = C.hex('${s['color']}');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: col, width: 4)),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(children: [
        Row(children: [
          Text('${s['icon']}', style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 7),
          Expanded(
            child: Text('${s['name']}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          Badge2('${t['cnt']!.toInt()} txn', col),
        ]),
        const SizedBox(height: 7),
        Row2('Volume', money(t['vol']), bold: true),
        if (out) ...[
          Row2('Company payout', money(t['payout']), small: true),
          Row2('Customer charge', money(t['charge']), small: true),
          Row2('TDS', '−${money(t['tds'])}', small: true),
        ] else
          Row2('Income', money(t['net']), small: true),
        const Divider(height: 12),
        Row2('Net income', money(t['net']), bold: true, color: col),
      ]),
    );
  }

  Future<void> _open(Widget f) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => f, fullscreenDialog: true));
    if (ok == true) _refresh();
  }
}

/// ----------------------------------------------------------------- CMS
class CmsTab extends StatefulWidget {
  final VoidCallback onChanged;
  const CmsTab({super.key, required this.onChanged});
  @override
  State<CmsTab> createState() => _CmsTabState();
}

class _CmsTabState extends State<CmsTab> {
  Future<Map<String, dynamic>> _load() async => {
        'parties': await Repo.i.parties(),
        'today': await Repo.i.cmsEntries(date: todayStr()),
        'all': await Repo.i.cmsEntries(),
      };

  void _refresh() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final parties = (snap.data!['parties'] as List).cast<Map<String, Object?>>();
        final tod = (snap.data!['today'] as List).cast<Map<String, Object?>>();
        final all = (snap.data!['all'] as List).cast<Map<String, Object?>>();

        return ListView(padding: const EdgeInsets.all(14), children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: () => _open(const CmsForm()),
            child: const Text('💵 New CMS Pickup'),
          ),
          const SizedBox(height: 9),
          OutlinedButton(
            onPressed: () => _open(const PartyForm()),
            child: const Text('+ Add CMS Party'),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Aaj ka CMS',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 5),
                Row2('Collection', money(sumOf(tod, 'amount')), bold: true),
                Row2('Payout', money(sumOf(tod, 'payout'))),
                Row2('TDS', '−${money(sumOf(tod, 'tds'))}', color: C.error),
                const Divider(height: 12),
                Row2('Net income', money(sumOf(tod, 'net')),
                    bold: true, color: C.accent),
              ]),
            ),
          ),
          const Note('Ek baar rate feed karein — phir har pickup par payout '
              'aur TDS apne aap nikal jaayega.'),
          Sec('CMS Parties (${parties.length})'),
          if (parties.isEmpty)
            const Empty('🏢', 'Koi party nahi', sub: 'Upar se party add karein')
          else
            ...parties.map((p) {
              final mine = all.where((e) => e['party_id'] == p['id']).toList();
              return Tile(
                icon: '🏢',
                color: C.accent,
                edge: C.accent,
                title: '${p['name']}',
                sub: '${p['mode'] == 'percent' ? '${p['rate']}% per pickup' : '₹${p['rate']} fixed'}'
                    ' · TDS ${p['tds_pct']}%\n'
                    'Volume ${sm(sumOf(mine, 'amount'))} · ${mine.length} pickups',
                amount: money(sumOf(mine, 'net')),
                amountSub: 'net',
                amountColor: C.accent,
                onMenu: () async {
                  final r = await rowMenu(context, '${p['name']}');
                  if (r == 'edit' && mounted) {
                    _open(PartyForm(edit: p));
                  } else if (r == 'delete' && mounted) {
                    if (mine.isNotEmpty) {
                      toast(context, 'Is party ki ${mine.length} entries hain',
                          bg: C.warning);
                      return;
                    }
                    if (await confirm(context, 'Delete party?', '${p['name']}')) {
                      await Repo.i.del('cms_parties', p['id'] as int);
                      _refresh();
                    }
                  }
                },
              );
            }),
          const Sec('Recent Pickups'),
          if (all.isEmpty)
            const Empty('💵', 'Koi pickup nahi')
          else
            ...all.take(20).map((e) => Tile(
                  icon: '💵',
                  color: C.accent,
                  title: '${e['party']}',
                  sub: '${dmy('${e['date']}')} ${e['time']}'
                      '${e['ref'] != null && '${e['ref']}'.isNotEmpty ? ' · ${e['ref']}' : ''}\n'
                      'Payout ${moneynumOf(e['payout'])} − TDS ${moneynumOf(e['tds'])}',
                  amount: moneynumOf(e['amount']),
                  amountSub: '+${moneynumOf(e['net'])}',
                  onMenu: () async {
                    final r = await rowMenu(
                        context, '${e['party']} · ${moneynumOf(e['amount'])}');
                    if (r == 'edit' && mounted) {
                      _open(CmsForm(edit: e));
                    } else if (r == 'delete' && mounted) {
                      if (await confirm(context, 'Delete pickup?', 'Hisaab update ho jaayega.')) {
                        await Repo.i.del('cms_entries', e['id'] as int);
                        _refresh();
                      }
                    }
                  },
                )),
        ]);
      },
    );
  }

  Future<void> _open(Widget f) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => f, fullscreenDialog: true));
    if (ok == true) _refresh();
  }
}

/// -------------------------------------------------------------- PAYOUT
class PayoutTab extends StatefulWidget {
  final VoidCallback onChanged;
  const PayoutTab({super.key, required this.onChanged});
  @override
  State<PayoutTab> createState() => _PayoutTabState();
}

class _PayoutTabState extends State<PayoutTab> {
  Future<Map<String, dynamic>> _load() async => {
        'today': await Repo.i.payouts(date: todayStr()),
        'all': await Repo.i.payouts(),
        'comps': await Repo.i.companies(),
        'pending': await Repo.i.pendingPayouts(),
      };

  void _refresh() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final tod = (snap.data!['today'] as List).cast<Map<String, Object?>>();
        final all = (snap.data!['all'] as List).cast<Map<String, Object?>>();
        final comps = (snap.data!['comps'] as List).cast<Map<String, Object?>>();
        final pend = (snap.data!['pending'] as List).cast<Map<String, Object?>>();
        double s(String k) => sumOf(tod, k);

        return ListView(padding: const EdgeInsets.all(14), children: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.pink),
            onPressed: () => _open(const PayoutForm()),
            child: const Text('✋ Add Manual Payout'),
          ),
          const SizedBox(height: 14),
          const Note('Raat ko doosre portal ka hisaab — payout + TDS + extra income. '
              'Galat feed ho jaaye to agle din ⋮ se edit kar sakte hain.'),
          if (pend.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFF8EC),
                  border: Border.all(color: const Color(0xFFF5D9A8)),
                  borderRadius: BorderRadius.circular(9)),
              child: Row(children: [
                const Text('⚠️', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('Aaj ka payout baaki: ${pend.map((e) => e['name']).join(', ')}',
                      style: const TextStyle(fontSize: 11.5)),
                ),
              ]),
            ),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Aaj ka Manual Payout',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 5),
                Row2('Company payout', money(s('payout'))),
                Row2('Extra income', money(s('extra')), color: C.accent),
                Row2('TDS', '−${money(s('tds'))}', color: C.error),
                const Divider(height: 12),
                Row2('Net', money(s('net')), bold: true, color: C.accent),
              ]),
            ),
          ),
          const Sec('Company Mode'),
          ...comps.map((c2) => Tile(
                icon: c2['mode'] == 'auto' ? '⚡' : '✋',
                color: c2['mode'] == 'auto' ? C.accent : C.pink,
                title: '${c2['name']}',
                sub: c2['mode'] == 'auto'
                    ? 'Auto — app khud calculate karta hai'
                    : 'Manual — raat ko payout daalein',
                onMenu: () async {
                  final r = await rowMenu(context, '${c2['name']}', canEdit: false);
                  if (r == 'delete') return;
                },
                onTap: () async {
                  final newMode = c2['mode'] == 'auto' ? 'manual' : 'auto';
                  await Repo.i.edit('companies', c2['id'] as int, {'mode': newMode});
                  _refresh();
                  if (mounted) toast(context, '${c2['name']} ab $newMode mode par');
                },
              )),
          Sec('Payout History (${all.length})'),
          if (all.isEmpty)
            const Empty('✋', 'Koi manual payout nahi')
          else
            ...all.map((e) => Tile(
                  icon: '✋',
                  color: C.pink,
                  title: '${e['company']}',
                  sub: '${dmy('${e['date']}')}'
                      '${e['note'] != null && '${e['note']}'.isNotEmpty ? ' · ${e['note']}' : ''}\n'
                      'Payout ${moneynumOf(e['payout'])} + Extra ${moneynumOf(e['extra'])} − TDS ${moneynumOf(e['tds'])}',
                  amount: moneynumOf(e['net']),
                  amountSub: 'net',
                  amountColor: C.accent,
                  onMenu: () async {
                    final r = await rowMenu(context, '${e['company']} · ${dmy('${e['date']}')}');
                    if (r == 'edit' && mounted) {
                      _open(PayoutForm(edit: e));
                    } else if (r == 'delete' && mounted) {
                      if (await confirm(context, 'Delete payout?', 'Profit update ho jaayega.')) {
                        await Repo.i.del('manual_payouts', e['id'] as int);
                        _refresh();
                      }
                    }
                  },
                )),
        ]);
      },
    );
  }

  Future<void> _open(Widget f) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => f, fullscreenDialog: true));
    if (ok == true) _refresh();
  }
}

/// ---------------------------------------------------------------- CASH
class CashTab extends StatefulWidget {
  final VoidCallback onChanged;
  const CashTab({super.key, required this.onChanged});
  @override
  State<CashTab> createState() => _CashTabState();
}

class _CashTabState extends State<CashTab> {
  Future<Map<String, dynamic>> _load() async {
    final d = todayStr();
    return {
      'cash': await Repo.i.counterCash(),
      'floats': await Repo.i.floats(date: d),
      'cms': await Repo.i.cmsVolume(d),
      'aeps': await Repo.i.serviceTotals('aeps', d),
      'upi': await Repo.i.serviceTotals('upi', d),
      'tr': await Repo.i.serviceTotals('upitransfer', d),
      'rc': await Repo.i.serviceTotals('recharge', d),
      'deposits': await Repo.i.deposits(date: d),
      'banks': await Repo.i.banks(),
    };
  }

  void _refresh() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;
        final cash = d['cash'] as double;
        final floats = (d['floats'] as List).cast<Map<String, Object?>>();
        final deps = (d['deposits'] as List).cast<Map<String, Object?>>();
        final banks = (d['banks'] as List).cast<Map<String, Object?>>();
        final flTotal = floats.fold(0.0, (s, e) => s + numOf(e['amount']));
        final depTotal = deps.fold(0.0, (s, e) => s + numOf(e['amount']));
        final chgTotal = deps.fold(0.0, (s, e) => s + numOf(e['charge']));
        final out = (d['aeps'] as Map)['vol']! + (d['upi'] as Map)['vol']!;
        final inSvc = (d['tr'] as Map)['vol']! + (d['rc'] as Map)['vol']!;

        return ListView(padding: const EdgeInsets.all(14), children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [C.warning, Color(0xFFFFB347)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Counter Cash in Hand',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(money(cash),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              const Text('Staff ke paas itna cash hona chahiye',
                  style: TextStyle(color: Colors.white70, fontSize: 10.5)),
            ]),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: C.warning),
                onPressed: () => _open(const FloatForm()),
                child: const Text('💰 Cash Float', style: TextStyle(fontSize: 12.5)),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: FilledButton(
                onPressed: () => _open(const DepositForm()),
                child: const Text('🏦 Deposit', style: TextStyle(fontSize: 12.5)),
              ),
            ),
          ]),
          const Sec('Aaj ka Cash Flow'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                Row2('💰 Float diya', '+${money(flTotal)}', color: C.accent),
                Row2('💵 CMS se aaya', '+${money(d['cms'])}', color: C.accent),
                Row2('➡️ Transfer + Recharge', '+${money(inSvc)}', color: C.accent),
                Row2('👆 AEPS/UPI cashout', '−${money(out)}', color: C.error),
                Row2('🏦 Bank jama', '−${money(depTotal)}', color: C.error),
                const Divider(height: 14),
                Row2('Counter mein hona chahiye', money(cash),
                    bold: true, color: C.warning),
              ]),
            ),
          ),
          Sec('Aaj ke Deposits',
              trailing: Text('charge ${money(chgTotal)}',
                  style: const TextStyle(fontSize: 11, color: C.error))),
          if (deps.isEmpty)
            const Empty('🏦', 'Aaj koi deposit nahi')
          else
            ...deps.map((e) {
              final ch = numOf(e['charge']);
              return Tile(
                icon: '🏦',
                color: C.primary,
                title: '${e['mode']} · ${e['bank']}',
                sub: '${e['account']}\n'
                    '${ch > 0 ? 'Charge ${money(ch)}' : 'No charge'}'
                    '${e['utr'] != null && '${e['utr']}'.isNotEmpty ? ' · ${e['utr']}' : ''}',
                amount: '+${moneynumOf(e['amount'])}',
                amountColor: C.accent,
                amountSub: ch > 0 ? '−${money(ch)}' : null,
                onMenu: () async {
                  final r = await rowMenu(context, '${e['mode']} · ${moneynumOf(e['amount'])}');
                  if (r == 'edit' && mounted) {
                    _open(DepositForm(edit: e));
                  } else if (r == 'delete' && mounted) {
                    if (await confirm(context, 'Delete deposit?', 'Wallet update ho jaayega.')) {
                      await Repo.i.del('deposits', e['id'] as int);
                      _refresh();
                    }
                  }
                },
              );
            }),
          const Sec('Bank Deposit Charges'),
          ...banks.map((b) {
            final r = numOf(b['chg_rate']);
            final txt = r <= 0
                ? 'FREE'
                : (b['chg_mode'] == 'percent' ? '$r%' : '₹$r');
            return Tile(
              icon: '🏦',
              color: r > 0 ? C.error : C.accent,
              title: '${b['bank']}',
              sub: '${b['company']}\n'
                  '${r <= 0 ? 'No charge' : (b['chg_mode'] == 'percent' ? '$r% of amount' : '₹$r per transaction')}',
              amount: txt,
              amountColor: r > 0 ? C.error : C.accent,
            );
          }),
          if (floats.isNotEmpty) ...[
            const Sec('Aaj ke Cash Floats'),
            ...floats.map((f) => Tile(
                  icon: '💰',
                  color: C.warning,
                  title: 'Staff ko float diya',
                  sub: '${f['time']}${f['note'] != null && '${f['note']}'.isNotEmpty ? ' · ${f['note']}' : ''}',
                  amount: moneynumOf(f['amount']),
                  amountColor: C.warning,
                  onMenu: () async {
                    final r = await rowMenu(context, 'Cash float', canEdit: false);
                    if (r == 'delete' && mounted) {
                      await Repo.i.del('cash_floats', f['id'] as int);
                      _refresh();
                    }
                  },
                )),
          ],
        ]);
      },
    );
  }

  Future<void> _open(Widget f) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => f, fullscreenDialog: true));
    if (ok == true) _refresh();
  }
}

/// CMS Party form (yahin rakha kyunki sirf CMS tab use karta hai)
class PartyForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const PartyForm({super.key, this.edit});
  @override
  State<PartyForm> createState() => _PartyFormState();
}

class _PartyFormState extends State<PartyForm> {
  final _name = TextEditingController();
  final _rate = TextEditingController();
  final _tds = TextEditingController(text: '5');
  String _mode = 'percent';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _name.text = '${e['name']}';
      _rate.text = '${e['rate']}';
      _tds.text = '${e['tds_pct']}';
      _mode = '${e['mode']}';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.edit == null ? 'Add CMS Party' : 'Edit CMS Party')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          F(_name, 'Party Name *', hint: 'e.g. Bajaj Finance'),
          const Text('Payout Type',
              style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Wrap(spacing: 7, children: [
            for (final m in [
              ['percent', 'Percentage'],
              ['fixed', 'Fixed per pickup']
            ])
              ChoiceChip(
                label: Text(m[1], style: const TextStyle(fontSize: 12)),
                selected: _mode == m[0],
                selectedColor: C.primary,
                labelStyle: TextStyle(
                    color: _mode == m[0] ? Colors.white : C.text,
                    fontWeight: FontWeight.w600),
                onSelected: (_) => setState(() => _mode = m[0]),
              ),
          ]),
          const SizedBox(height: 14),
          F(_rate, _mode == 'percent' ? 'Rate % *' : 'Fixed ₹ per pickup *',
              type: TextInputType.number, hint: _mode == 'percent' ? '0.35' : '12'),
          F(_tds, 'TDS %', type: TextInputType.number),
          const Note('Ek baar feed karein — aage har pickup auto calculate hoga.'),
          FilledButton(
            onPressed: _busy ? null : () async {
              if (_name.text.trim().isEmpty) {
                return toast(context, 'Naam zaroori hai', bg: C.error);
              }
              setState(() => _busy = true);
              final row = {
                'name': _name.text.trim(),
                'mode': _mode,
                'rate': parseD(_rate),
                'tds_pct': parseD(_tds),
                'active': 1,
              };
              widget.edit == null
                  ? await Repo.i.add('cms_parties', row)
                  : await Repo.i.edit('cms_parties', widget.edit!['id'] as int, row);
              if (mounted) Navigator.pop(context, true);
            },
            child: Text(_busy ? 'Saving…' : '💾 Save'),
          ),
        ]),
      );
}

import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import 'tabs.dart';

/// Recovery ke 4 tarike — paisa kahan jaata hai wo har tarike mein alag hai
class RMethod {
  final String code, name, desc, tag, icon;
  final Color color;
  final String to; // wallet | myacc | cash
  const RMethod(this.code, this.name, this.desc, this.tag, this.icon,
      this.color, this.to);

  static const all = [
    RMethod('portal_reverse', 'Portal Reverse',
        'Retailer ne usi portal par balance wapas kiya',
        'Wallet +', '↩️', C.accent, 'wallet'),
    RMethod('company_bank', 'Company Bank Deposit',
        'Retailer ne company ke bank account mein jama kiya',
        'Wallet +', '🏦', C.accent, 'wallet'),
    RMethod('my_account', 'Mere Account mein',
        'UPI ya bank transfer mere personal/firm account par',
        'Mera A/c +', '📱', C.primaryLight, 'myacc'),
    RMethod('cash_agent', 'Cash — Collection',
        'Retailer se cash collect kiya',
        'Cash +', '💵', C.warning, 'cash'),
  ];

  static RMethod of(String code) =>
      all.firstWhere((m) => m.code == code, orElse: () => all.first);
}

/// ------------------------------------------------------- RETAILER LIST
class RetailersScreen extends StatefulWidget {
  const RetailersScreen({super.key});
  @override
  State<RetailersScreen> createState() => _RetailersScreenState();
}

class _RetailersScreenState extends State<RetailersScreen> {
  Future<Map<String, dynamic>> _load() async {
    final list = await Repo.i.retailers();
    final dues = <int, double>{};
    final issued = <int, double>{};
    final recovered = <int, double>{};
    for (final r in list) {
      final id = r['id'] as int;
      dues[id] = await Repo.i.retailerDue(id);
      issued[id] = await Repo.i.retailerIssued(id);
      recovered[id] = await Repo.i.retailerRecovered(id);
    }
    return {
      'list': list,
      'dues': dues,
      'issued': issued,
      'recovered': recovered,
      'totalDue': await Repo.i.totalDue(),
      'todayIssued': await Repo.i.todayIssued(),
      'todayRecovered': await Repo.i.todayRecovered(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Retailers')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (c, s) {
          if (s.hasError) return ErrBox(s.error!);
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = (s.data!['list'] as List).cast<Map<String, Object?>>();
          final dues = s.data!['dues'] as Map<int, double>;
          final issued = s.data!['issued'] as Map<int, double>;
          final recovered = s.data!['recovered'] as Map<int, double>;

          return ListView(padding: const EdgeInsets.all(14), children: [
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.purple),
                  onPressed: () => _open(const IssueForm()),
                  child: const Text('📤 Fund Dein',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.accent),
                  onPressed: () => _open(const RecoveryForm()),
                  child: const Text('📥 Collection',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ]),
            const SizedBox(height: 9),
            OutlinedButton(
              onPressed: () => _open(const RetailerForm()),
              child: const Text('+ Naya Retailer'),
            ),
            const SizedBox(height: 14),

            // Summary
            AppCard(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                Row2('Aaj diya', money(s.data!['todayIssued']),
                    color: C.purple),
                Row2('Aaj aaya', money(s.data!['todayRecovered']),
                    color: C.accent),
                const Divider(height: 14),
                Row2('Total Outstanding', money(s.data!['totalDue']),
                    bold: true, color: C.error),
              ]),
            ),

            Sec('Retailers (${list.length})'),
            if (list.isEmpty)
              const Empty('🏪', 'Koi retailer nahi',
                  sub: 'Jinko aap fund dete hain unhe add karein')
            else
              ...list.map((r) {
                final id = r['id'] as int;
                final due = dues[id] ?? 0;
                final limit = numOf(r['credit_limit']);
                final over = due > limit;
                return Tile(
                  icon: '🏪',
                  color: C.purple,
                  edge: due > 0 ? (over ? C.error : C.purple) : C.accent,
                  title: '${r['name']}'
                      '${over ? '  ⚠️ LIMIT+' : ''}',
                  sub: '${r['phone'] ?? ''}'
                      '${r['area'] != null && '${r['area']}'.isNotEmpty ? ' · ${r['area']}' : ''}\n'
                      'Diya ${sm(issued[id])} · Aaya ${sm(recovered[id])}',
                  amount: money(due),
                  amountSub: due > 0 ? 'baaki' : 'clear',
                  amountColor: due > 0 ? (over ? C.error : C.purple) : C.accent,
                  onTap: () => _open(RetailerStatement(retailer: r)),
                  onMenu: () async {
                    final x = await rowMenu(context, '${r['name']}');
                    if (x == 'edit' && mounted) {
                      _open(RetailerForm(edit: r));
                    } else if (x == 'delete' && mounted) {
                      if (due > 0) {
                        toast(context,
                            '${r['name']} par ${money(due)} baaki hai — pehle collection karein',
                            bg: C.warning);
                        return;
                      }
                      final go = await confirm(context, 'Delete retailer?',
                          '${r['name']} aur uska poora hisaab hat jaayega.');
                      // dialog ke doran screen band ho sakti hai
                      if (!go || !mounted) return;
                      await Repo.i.del('retailers', id);
                      if (mounted) setState(() {});
                    }
                  },
                );
              }),
          ]);
        },
      ),
    );
  }

  Future<void> _open(Widget w) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => w, fullscreenDialog: true));
    if (ok == true || ok == null) setState(() {});
  }
}

/// -------------------------------------------------- RETAILER STATEMENT
class RetailerStatement extends StatefulWidget {
  final Map<String, Object?> retailer;
  const RetailerStatement({super.key, required this.retailer});
  @override
  State<RetailerStatement> createState() => _RetailerStatementState();
}

class _RetailerStatementState extends State<RetailerStatement> {
  int get _rid => widget.retailer['id'] as int;

  Future<Map<String, dynamic>> _load() async => {
        'issues': await Repo.i.retailerIssues(rid: _rid),
        'recoveries': await Repo.i.retailerRecoveries(rid: _rid),
        'due': await Repo.i.retailerDue(_rid),
        'issued': await Repo.i.retailerIssued(_rid),
        'recovered': await Repo.i.retailerRecovered(_rid),
        'byMethod': await Repo.i.recoveryByMethod(rid: _rid),
      };

  @override
  Widget build(BuildContext context) {
    final r = widget.retailer;
    return Scaffold(
      appBar: AppBar(title: Text('${r['name']}')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _load(),
        builder: (c, s) {
          if (s.hasError) return ErrBox(s.error!);
          if (!s.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final issues =
              (s.data!['issues'] as List).cast<Map<String, Object?>>();
          final recs =
              (s.data!['recoveries'] as List).cast<Map<String, Object?>>();
          final byMethod = s.data!['byMethod'] as Map<String, double>;
          final due = s.data!['due'] as double;

          // dono milakar date ke hisaab se
          final all = <Map<String, Object?>>[
            ...issues.map((e) => {...e, '_kind': 'issue'}),
            ...recs.map((e) => {...e, '_kind': 'recovery'}),
          ]..sort((a, b) => '${b['date']}'.compareTo('${a['date']}'));

          return ListView(padding: const EdgeInsets.all(14), children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [C.purple, Color(0xFF8B6FD8)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['name']}',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(money(due),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w700)),
                    ),
                    const Text('Outstanding — wapas aana baaki',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 10.5)),
                    const SizedBox(height: 12),
                    Row(children: [
                      _b('Total Diya', sm(s.data!['issued'])),
                      _b('Wapas Aaya', sm(s.data!['recovered'])),
                      _b('Limit', sm(numOf(r['credit_limit']))),
                    ]),
                  ]),
            ),
            const SizedBox(height: 12),

            // Contact
            if ('${r['phone'] ?? ''}'.isNotEmpty ||
                '${r['shop'] ?? ''}'.isNotEmpty)
              AppCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if ('${r['phone'] ?? ''}'.isNotEmpty)
                        Text('📱 ${r['phone']}',
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      if ('${r['shop'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text('${r['shop']}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                      if ('${r['area'] ?? ''}'.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('${r['area']}',
                              style: const TextStyle(
                                  fontSize: 11.5, color: C.muted)),
                        ),
                    ]),
              ),

            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.purple),
                  onPressed: () => _open(IssueForm(retailerId: _rid)),
                  child:
                      const Text('📤 Fund', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.accent),
                  onPressed: () => _open(RecoveryForm(retailerId: _rid)),
                  child: const Text('📥 Collection',
                      style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ]),

            // Method breakup
            if (byMethod.isNotEmpty) ...[
              const Sec('Collection kaise aaya'),
              AppCard(
                padding: const EdgeInsets.all(13),
                child: Column(
                  children: byMethod.entries.map((e) {
                    final m = RMethod.of(e.key);
                    return Row2('${m.icon} ${m.name}', money(e.value),
                        color: m.color);
                  }).toList(),
                ),
              ),
            ],

            Sec('Poora Hisaab (${all.length})'),
            if (all.isEmpty)
              const Empty('📭', 'Koi entry nahi')
            else
              ...all.map((e) => e['_kind'] == 'issue'
                  ? _issueTile(e)
                  : _recoveryTile(e)),
          ]);
        },
      ),
    );
  }

  Widget _b(String k, String v) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(v,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _issueTile(Map<String, Object?> e) => Tile(
        icon: '📤',
        color: C.purple,
        title: 'Fund diya',
        sub: '${dmy('${e['date']}')} ${e['time'] ?? ''} · ${e['company']}\n'
            '${e['account']}'
            '${e['ref'] != null && '${e['ref']}'.isNotEmpty ? ' · ${e['ref']}' : ''}',
        amount: '−${money(numOf(e['amount']))}',
        amountColor: C.purple,
        onMenu: () async {
          final x = await rowMenu(
              context, 'Fund ${money(numOf(e['amount']))}');
          if (x == 'edit' && mounted) {
            _open(IssueForm(retailerId: _rid, edit: e));
          } else if (x == 'delete' && mounted) {
            if (await confirm(context, 'Delete entry?',
                'Wallet aur outstanding update ho jaayega.')) {
              await Repo.i.del('retailer_issues', e['id'] as int);
              setState(() {});
            }
          }
        },
      );

  Widget _recoveryTile(Map<String, Object?> e) {
    final m = RMethod.of('${e['method']}');
    final detail = switch ('${e['method']}') {
      'company_bank' =>
        '${e['bank_name'] ?? ''}${e['utr'] != null && '${e['utr']}'.isNotEmpty ? ' · ${e['utr']}' : ''}',
      'my_account' => '${e['utr'] ?? ''}',
      'cash_agent' => '${e['receipt'] ?? ''}',
      _ => '${e['ref'] ?? ''}',
    };
    return Tile(
      icon: m.icon,
      color: m.color,
      title: 'Aaya · ${m.name}',
      sub: '${dmy('${e['date']}')} ${e['time'] ?? ''} · ${e['company']}'
          '${detail.trim().isNotEmpty ? '\n$detail' : ''}',
      amount: '+${money(numOf(e['amount']))}',
      amountSub: m.tag,
      amountColor: m.color,
      onMenu: () async {
        final x =
            await rowMenu(context, 'Collection ${money(numOf(e['amount']))}');
        if (x == 'edit' && mounted) {
          _open(RecoveryForm(retailerId: _rid, edit: e));
        } else if (x == 'delete' && mounted) {
          if (await confirm(context, 'Delete entry?',
              'Wallet aur outstanding update ho jaayega.')) {
            await Repo.i.del('retailer_recoveries', e['id'] as int);
            setState(() {});
          }
        }
      },
    );
  }

  Future<void> _open(Widget w) async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => w, fullscreenDialog: true));
    if (mounted) setState(() {});
  }
}

/// ------------------------------------------------------- RETAILER FORM
class RetailerForm extends StatefulWidget {
  final Map<String, Object?>? edit;
  const RetailerForm({super.key, this.edit});
  @override
  State<RetailerForm> createState() => _RetailerFormState();
}

class _RetailerFormState extends State<RetailerForm> {
  late final _name = TextEditingController(text: '${widget.edit?['name'] ?? ''}');
  late final _phone =
      TextEditingController(text: '${widget.edit?['phone'] ?? ''}');
  late final _shop = TextEditingController(text: '${widget.edit?['shop'] ?? ''}');
  late final _area = TextEditingController(text: '${widget.edit?['area'] ?? ''}');
  late final _limit = TextEditingController(
      text: numOf(widget.edit?['credit_limit']).toStringAsFixed(0));
  bool _busy = false;

  /// Retailer kis Distributor ID ke andar map hai.
  /// Sirf wo IDs jinme "retailer funding" ON hai.
  int? _accId;
  List<Map<String, Object?>> _funders = [];
  bool _loading = true;
  Object? _err;

  @override
  void initState() {
    super.initState();
    _accId = widget.edit?['account_id'] as int?;
    _load();
  }

  Future<void> _load() async {
    try {
      final f = await Repo.i.fundingAccounts();
      if (!mounted) return;
      setState(() {
        _funders = f;
        // Sirf ek hi funding ID ho to apne aap chun lein
        _accId ??= f.length == 1 ? f.first['id'] as int : null;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _err = e; _loading = false; });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _shop, _area, _limit]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.edit == null ? 'Naya Retailer' : 'Edit Retailer')),
        body: _err != null
            ? ErrBox(_err!)
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : _funders.isEmpty
                    ? _noFunder()
                    : _body(),
      );

  /// Koi funding ID hi nahi — user ko raasta dikhaayein
  Widget _noFunder() => Padding(
        padding: const EdgeInsets.all(18),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Empty('🤝', 'Koi funding ID nahi',
              sub: 'Retailer hamesha kisi Distributor ID ke andar map hota hai.\n\n'
                  'Pehle jaayein: More → Company IDs → apni Distributor ID → Edit → '
                  '"Kya aap retailer ko funding karte hain is ID se?" ON karein.'),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Wapas'),
          ),
        ]),
      );

  Widget _body() => ListView(padding: const EdgeInsets.all(14), children: [
        F(_name, 'Retailer Name *', hint: 'e.g. Shyam Mobile Shop'),
        // ---- Distributor ID mapping ----
        InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Kis Distributor ID ke andar? *',
            contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _accId,
              isExpanded: true,
              isDense: true,
              hint: const Text('Chunein', style: TextStyle(fontSize: 13)),
              items: _funders
                  .map((a) => DropdownMenuItem(
                        value: a['id'] as int,
                        child: Text('${a['company']} · ${a['label']}',
                            style: const TextStyle(fontSize: 13)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _accId = v),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Note('Is retailer ko fund dene par ISI ID ka wallet minus hoga, '
            'aur wapsi par plus. Cash mein wapas mile to wo aapke "Mera Cash" '
            'mein jaayega (CMS ki tarah).'),
        F(_phone, 'Mobile Number', type: TextInputType.phone),
        F(_shop, 'Shop ka naam'),
        F(_area, 'Area / Address'),
        F(_limit, 'Credit Limit', type: TextInputType.number),
        const Note('Credit limit se zyada udhaar hone par list mein '
            'laal warning dikhegi.'),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.purple),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Save'),
        ),
      ]);

  Future<void> _save() async {
    setState(() => _busy = true);
    final err = await Repo.i.saveRetailer(
      id: widget.edit?['id'] as int?,
      name: _name.text,
      accountId: _accId,
      phone: _phone.text,
      shop: _shop.text,
      area: _area.text,
      creditLimit: parseD(_limit) <= 0 ? 30000.0 : parseD(_limit),
    );
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      toast(context, err, bg: C.error);
      return;
    }
    Navigator.pop(context, true);
  }
}

/// ---------------------------------------------------------- ISSUE FORM
class IssueForm extends StatefulWidget {
  final int? retailerId;
  final Map<String, Object?>? edit;
  const IssueForm({super.key, this.retailerId, this.edit});
  @override
  State<IssueForm> createState() => _IssueFormState();
}

class _IssueFormState extends State<IssueForm> {
  final _amt = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  int? _rid, _acc;
  List<Map<String, Object?>> _retailers = [], _accs = [];
  double _currentDue = 0, _wallet = 0;
  bool _busy = false, _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _amt.text = numOf(e['amount']).toStringAsFixed(0);
      _ref.text = '${e['ref'] ?? ''}';
      _note.text = '${e['note'] ?? ''}';
      _rid = e['retailer_id'] as int?;
      _acc = e['account_id'] as int?;
    }
    _rid ??= widget.retailerId;
    _load();
  }

  Future<void> _load() async {
    _retailers = await Repo.i.retailers();
    // Fund sirf un IDs se jaata hai jinme "retailer funding" ON hai.
    _accs = await Repo.i.fundingAccounts();
    _rid ??= _retailers.isNotEmpty ? _retailers.first['id'] as int : null;
    // Retailer jis ID mein map hai wahi apne aap chun lein.
    _acc ??= _mappedAcc(_rid) ?? (_accs.isNotEmpty ? _accs.first['id'] as int : null);
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// Retailer ki mapped Distributor ID
  int? _mappedAcc(int? rid) {
    if (rid == null) return null;
    for (final r in _retailers) {
      if (r['id'] == rid) {
        final a = r['account_id'] as int?;
        if (a != null && _accs.any((x) => x['id'] == a)) return a;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    if (_rid != null) _currentDue = await Repo.i.retailerDue(_rid!);
    if (_acc != null) _wallet = await Repo.i.wallet(_acc!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fund Dein')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_retailers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fund Dein')),
        body: const Empty('🏪', 'Koi retailer nahi',
            sub: 'Pehle retailer add karein'),
      );
    }
    if (_accs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fund Dein')),
        body: const Empty('🤝', 'Koi funding ID nahi',
            sub: 'More → Company IDs → Distributor ID → Edit → '
                '"Kya aap retailer ko funding karte hain is ID se?" ON karein'),
      );
    }

    final amt = parseD(_amt);
    final after = _currentDue + amt;
    final r = _retailers.firstWhere((x) => x['id'] == _rid,
        orElse: () => _retailers.first);
    final limit = numOf(r['credit_limit']);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null ? 'Retailer ko Fund' : 'Edit Fund')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _dd<int>('Retailer', _rid,
            _retailers
                .map((x) => DropdownMenuItem(
                    value: x['id'] as int, child: Text('${x['name']}')))
                .toList(), (v) {
          setState(() {
            _rid = v;
            // Retailer badla to uski apni mapped ID par switch
            _acc = _mappedAcc(v) ?? _acc;
          });
          _refresh();
        }),
        _dd<int>('Kis Company ID se?', _acc,
            _accs
                .map((a) => DropdownMenuItem(
                    value: a['id'] as int,
                    child: Text('${a['company']} — ${a['label']}',
                        overflow: TextOverflow.ellipsis)))
                .toList(), (v) {
          setState(() => _acc = v);
          _refresh();
        }),
        F(_amt, 'Amount *',
            type: TextInputType.number, onChanged: (_) => setState(() {})),
        F(_ref, 'Reference / Txn ID'),
        F(_note, 'Note'),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: after > limit
                ? const Color(0xFFFDF0F0)
                : const Color(0xFFF0F4FB),
            border: Border.all(
                color: after > limit
                    ? const Color(0xFFF0C0C0)
                    : const Color(0xFFC5D4EE)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Row2('Wallet mein abhi', money(_wallet), small: true),
            Row2('Abhi baaki hai', money(_currentDue)),
            Row2('Retailer limit', money(limit), small: true),
            const Divider(height: 12),
            Row2('Is entry ke baad', money(after),
                bold: true, color: after > limit ? C.error : C.purple),
            if (after > limit)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('⚠️ Credit limit se zyada ho jaayega',
                    style: TextStyle(
                        fontSize: 11, color: C.error, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        const Note('Ye paisa company wallet se katega aur retailer ke '
            'khaate mein udhaar chadhega.'),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.purple),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Save'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final amt = parseD(_amt);
    if (amt <= 0) return toast(context, 'Amount daalein', bg: C.error);
    if (_rid == null || _acc == null) {
      return toast(context, 'Retailer aur ID chunein', bg: C.error);
    }
    if (amt > _wallet && widget.edit == null) {
      final go = await confirm(context, 'Wallet kam hai',
          'Wallet mein sirf ${money(_wallet)} hai. Phir bhi entry karein?',
          ok: 'Haan');
      if (!go) return;
    }
    setState(() => _busy = true);
    await Repo.i.saveIssue(
      id: widget.edit?['id'] as int?,
      retailerId: _rid!,
      accountId: _acc!,
      amount: amt,
      ref: _ref.text.trim(),
      note: _note.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// ------------------------------------------------------- RECOVERY FORM
class RecoveryForm extends StatefulWidget {
  final int? retailerId;
  final Map<String, Object?>? edit;
  const RecoveryForm({super.key, this.retailerId, this.edit});
  @override
  State<RecoveryForm> createState() => _RecoveryFormState();
}

class _RecoveryFormState extends State<RecoveryForm> {
  final _amt = TextEditingController();
  final _utr = TextEditingController();
  final _receipt = TextEditingController();
  final _ref = TextEditingController();
  final _note = TextEditingController();
  int? _rid, _acc, _bank;
  String _method = 'portal_reverse';
  List<Map<String, Object?>> _retailers = [], _accs = [], _banks = [];
  double _currentDue = 0;
  bool _busy = false, _loading = true;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _amt.text = numOf(e['amount']).toStringAsFixed(0);
      _utr.text = '${e['utr'] ?? ''}';
      _receipt.text = '${e['receipt'] ?? ''}';
      _ref.text = '${e['ref'] ?? ''}';
      _note.text = '${e['note'] ?? ''}';
      _rid = e['retailer_id'] as int?;
      _acc = e['account_id'] as int?;
      _bank = e['bank_id'] as int?;
      _method = '${e['method']}';
    }
    _rid ??= widget.retailerId;
    _load();
  }

  Future<void> _load() async {
    _retailers = await Repo.i.retailers();
    // Wapsi bhi usi funding ID mein hoti hai jisse fund gaya tha.
    _accs = await Repo.i.fundingAccounts();
    _banks = await Repo.i.banks();
    _rid ??= _retailers.isNotEmpty ? _retailers.first['id'] as int : null;
    _acc ??= _mappedAcc(_rid) ?? (_accs.isNotEmpty ? _accs.first['id'] as int : null);
    _bank ??= _banks.isNotEmpty ? _banks.first['id'] as int : null;
    await _refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// Retailer ki mapped Distributor ID
  int? _mappedAcc(int? rid) {
    if (rid == null) return null;
    for (final r in _retailers) {
      if (r['id'] == rid) {
        final a = r['account_id'] as int?;
        if (a != null && _accs.any((x) => x['id'] == a)) return a;
      }
    }
    return null;
  }

  Future<void> _refresh() async {
    if (_rid != null) _currentDue = await Repo.i.retailerDue(_rid!);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_retailers.isEmpty || _accs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Collection')),
        body: Empty(_retailers.isEmpty ? '🏪' : '🆔',
            _retailers.isEmpty ? 'Koi retailer nahi' : 'Koi Company ID nahi'),
      );
    }

    final amt = parseD(_amt);
    final after = _currentDue - amt;
    final m = RMethod.of(_method);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit == null ? 'Collection Entry' : 'Edit Collection')),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        _dd<int>('Retailer', _rid,
            _retailers
                .map((x) => DropdownMenuItem(
                    value: x['id'] as int, child: Text('${x['name']}')))
                .toList(), (v) {
          setState(() {
            _rid = v;
            _acc = _mappedAcc(v) ?? _acc;
          });
          _refresh();
        }),
        _dd<int>('Kis Company ID ka?', _acc,
            _accs
                .map((a) => DropdownMenuItem(
                    value: a['id'] as int,
                    child: Text('${a['company']} — ${a['label']}',
                        overflow: TextOverflow.ellipsis)))
                .toList(),
            (v) => setState(() => _acc = v)),
        F(_amt, 'Amount *',
            type: TextInputType.number, onChanged: (_) => setState(() {})),

        const Text('Paisa kaise wapas aaya? *',
            style: TextStyle(
                fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 7),
        ...RMethod.all.map((x) => GestureDetector(
              onTap: () => setState(() => _method = x.code),
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _method == x.code ? const Color(0xFFF0F4FB) : Colors.white,
                  border: Border.all(
                      color: _method == x.code ? C.primary : C.divider,
                      width: _method == x.code ? 1.5 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Text('${x.icon} ${x.name}',
                            style: const TextStyle(
                                fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Badge2(x.tag, x.color),
                      ]),
                      const SizedBox(height: 2),
                      Text(x.desc,
                          style: const TextStyle(fontSize: 10.5, color: C.muted)),
                    ]),
              ),
            )),
        const SizedBox(height: 6),

        // Method wise extra fields
        if (_method == 'company_bank') ...[
          _dd<int>('Kis bank mein jama hua?', _bank,
              _banks
                  .map((b) => DropdownMenuItem(
                      value: b['id'] as int,
                      child: Text('${b['company']} — ${b['bank']}',
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              (v) => setState(() => _bank = v)),
          F(_utr, 'UTR / Reference'),
        ] else if (_method == 'my_account') ...[
          F(_utr, 'UTR / UPI Reference'),
          const Note('Ye paisa company wallet mein NAHI jaayega — aapke apne '
              'account mein aayega. Retailer ka udhaar phir bhi kam hoga.'),
        ] else if (_method == 'cash_agent') ...[
          F(_receipt, 'Receipt Number'),
          const Note('Cash aapke haath mein aayega — Counter Cash badhega.'),
        ] else
          F(_ref, 'Reverse Reference No.'),

        F(_note, 'Note'),
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F7F4),
            border: Border.all(color: const Color(0xFFBFE3D3)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(children: [
            Row2('Abhi baaki hai', money(_currentDue)),
            Row2('Ye collection', '−${money(amt)}', color: m.color),
            const Divider(height: 12),
            Row2('Baad mein baaki', money(after < 0 ? 0 : after),
                bold: true, color: after <= 0 ? C.accent : C.purple),
            if (after < 0)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('⚠️ Baaki se zyada amount hai',
                    style: TextStyle(
                        fontSize: 11, color: C.warning, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.accent),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : '💾 Save'),
        ),
      ]),
    );
  }

  Future<void> _save() async {
    final amt = parseD(_amt);
    if (amt <= 0) return toast(context, 'Amount daalein', bg: C.error);
    if (_rid == null || _acc == null) {
      return toast(context, 'Retailer aur ID chunein', bg: C.error);
    }
    if (amt > _currentDue && widget.edit == null) {
      final go = await confirm(context, 'Zyada amount',
          'Baaki sirf ${money(_currentDue)} hai. Phir bhi save karein?',
          ok: 'Haan');
      if (!go) return;
    }
    setState(() => _busy = true);
    await Repo.i.saveRecovery(
      id: widget.edit?['id'] as int?,
      retailerId: _rid!,
      accountId: _acc!,
      amount: amt,
      method: _method,
      bankId: _method == 'company_bank' ? _bank : null,
      utr: _utr.text.trim(),
      receipt: _receipt.text.trim(),
      ref: _ref.text.trim(),
      note: _note.text.trim(),
    );
    if (mounted) Navigator.pop(context, true);
  }
}

/// Shared dropdown (version-safe)
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

import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';
import '../services/backup.dart';
import '../services/pin.dart';
import '../services/voice.dart';
import 'pin_reset.dart';
import 'retailers.dart';
import 'tabs.dart';

/// More tab — masters, rates, backup, settings
class MoreTab extends StatefulWidget {
  final VoidCallback onChanged;
  final VoidCallback onLogout;
  const MoreTab({super.key, required this.onChanged, required this.onLogout});
  @override
  State<MoreTab> createState() => _MoreTabState();
}

class _MoreTabState extends State<MoreTab> {
  bool _voiceOn = true;

  @override
  void initState() {
    super.initState();
    Voice.i.isOn().then((v) {
      if (mounted) setState(() => _voiceOn = v);
    });
  }

  Future<Map<String, dynamic>> _load() async => {
        'wallet': await Repo.i.totalWallet(),
        'myCash': await Repo.i.myCash(),
        'cash': await Repo.i.counterCash(),
        'due': await Repo.i.totalDue(),
        'lastBackup': await BackupService.lastBackup(),
      };

  void _refresh() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _load(),
      builder: (c, s) {
        if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data!;
        final lb = d['lastBackup'] as DateTime?;
        return ListView(padding: const EdgeInsets.all(14), children: [
          // Money snapshot
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Poora Paisa',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 6),
                Row2('💼 Company wallets', money(d['wallet']), bold: true),
                Row2('👤 Mera cash', money(d['myCash']), color: C.primary, bold: true),
                Row2('🏪 Counter cash', money(d['cash']), color: C.warning, bold: true),
                InkWell(
                  onTap: () => _go(const RetailersScreen()),
                  child: Row2('🏪 Retailer outstanding  ›', money(d['due']),
                      color: C.purple, bold: true),
                ),
                const Divider(height: 14),
                Row2('Total exposure',
                    money(numOf(d['wallet']) + numOf(d['myCash']) + numOf(d['cash']) + numOf(d['due'])),
                    bold: true),
              ]),
            ),
          ),

          const Sec('Master Data'),
          _row('🏢', 'Companies', 'Add, edit, delete', () => _go(const CompaniesScreen())),
          _row('🆔', 'Company IDs', 'Distributor / Retailer ID',
              () => _go(const AccountsScreen())),
          _row('🏦', 'Banks & Deposit Charges', 'Charge rules yahan set karein',
              () => _go(const BanksScreen())),
          _row('⚙️', 'Service Rates', 'AEPS, UPI, Transfer, Recharge',
              () => _go(const RatesScreen())),
          _row('🏪', 'Retailers', 'Fund dena, collection, outstanding',
              () => _go(const RetailersScreen())),

          const Sec('Backup & Restore'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Column(children: [
                Row(children: [
                  const Text('☁️', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Last Backup',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        lb == null
                            ? 'Kabhi backup nahi hua'
                            : '${lb.day}/${lb.month}/${lb.year} ${lb.hour}:${lb.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 11, color: C.muted),
                      ),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: C.accent),
                  onPressed: () async {
                    try {
                      toast(context, 'Backup ban raha hai…');
                      final name = await BackupService.backupAndShare();
                      await BackupService.prune();
                      if (mounted) {
                        toast(context, 'Backup ready: $name');
                        _refresh();
                      }
                    } catch (e) {
                      if (mounted) toast(context, 'Backup fail: $e', bg: C.error);
                    }
                  },
                  child: const Text('☁️ Backup → Google Drive'),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share menu khulega → "Drive" ya "Save to Drive" tap karein',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: C.muted),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        try {
                          final path = await BackupService.backupLocalOnly();
                          if (mounted) {
                            toast(context, 'Phone mein save: ${path.split('/').last}');
                            _refresh();
                          }
                        } catch (e) {
                          if (mounted) toast(context, 'Fail: $e', bg: C.error);
                        }
                      },
                      child: const Text('💾 Phone mein', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final ok = await confirm(context, 'Restore backup?',
                            'Abhi ka saara data replace ho jaayega. Pehle backup le lein.',
                            ok: 'Restore');
                        if (!ok) return;
                        try {
                          final done = await BackupService.restoreFromFile();
                          if (mounted) {
                            toast(context, done ? 'Restore ho gaya' : 'Cancel');
                            _refresh();
                          }
                        } catch (e) {
                          if (mounted) toast(context, 'Restore fail: $e', bg: C.error);
                        }
                      },
                      child: const Text('📥 Restore', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          const Note(
            'Backup mein sab hai — database, CMS hisaab, shop entries, payouts, deposit '
            'charges, slips. Roz ek baar backup lein.\n\n'
            'Auto-sync bhi ho sakta hai — README mein Google Cloud setup guide hai (free, ~20 min).',
          ),

          const Sec('Awaaz'),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 8),
              child: Column(children: [
                SwitchListTile(
                  value: _voiceOn,
                  onChanged: (v) async {
                    await Voice.i.setOn(v);
                    if (!mounted) return;
                    setState(() => _voiceOn = v);
                    if (v) Voice.i.preview();
                  },
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('🔊 Hindi welcome awaaz',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    _voiceOn
                        ? 'App khulte hi Hindi mein swagat — har baar nayi line'
                        : 'Band hai — app chup-chaap khulegi',
                    style: const TextStyle(fontSize: 11, color: C.muted),
                  ),
                ),
                if (_voiceOn)
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Voice.i.preview(),
                        icon: const Text('▶️', style: TextStyle(fontSize: 12)),
                        label: const Text('Sunkar dekhein',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Voice.i.stop(),
                        icon: const Text('⏹', style: TextStyle(fontSize: 12)),
                        label: const Text('Rokein', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ]),
                if (_voiceOn)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Note('Phone ki apni awaaz use hoti hai — offline, '
                        'bilkul free. Kuch na sunai de to phone ki Settings → '
                        'Language → Text-to-speech mein Hindi install karein.'),
                  ),
              ]),
            ),
          ),

          const Sec('Security'),
          _row('🔑', 'Change PIN', '4 ya 6 digit', () => _go(const ChangePinScreen())),
          _row('🛟', 'PIN Recovery Setup',
              'Security question + recovery code',
              () => _go(const RecoverySetupScreen())),
          _row('👁️', 'Recovery Code Dekhein', 'Apna code phir se dekhein',
              _showCode),
          _row('🚪', 'Logout', 'App abhi lock karein', widget.onLogout),

          const Sec('About'),
          _row('ℹ️', 'FinFloat Pro v1.0', 'Digitronic Services', () {
            showAboutDialog(
              context: context,
              applicationName: 'FinFloat Pro',
              applicationVersion: '1.0.0',
              applicationLegalese: '© Digitronic Services',
              children: const [
                SizedBox(height: 10),
                Text(
                  'Offline Fintech Float Management System.\n\n'
                  'Saara data aapke phone mein SQLite database mein. Koi server nahi, '
                  'koi account nahi, koi tracking nahi. Internet sirf Google Drive '
                  'backup ke liye chahiye.',
                  style: TextStyle(fontSize: 12.5, height: 1.5),
                ),
              ],
            );
          }),
        ]);
      },
    );
  }

  Future<void> _showCode() async {
    final code = await PinService.recoveryCode();
    if (!mounted) return;
    if (code == null) {
      toast(context, 'Abhi recovery setup nahi kiya', bg: C.warning);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('🔑 Recovery Code'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
                color: C.primary, borderRadius: BorderRadius.circular(10)),
            child: Center(
              child: SelectableText(code,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                      fontFamily: 'monospace')),
            ),
          ),
          const SizedBox(height: 12),
          const Text('Kahin likh kar rakhein. PIN bhoolne par kaam aayega.',
              style: TextStyle(fontSize: 11.5, height: 1.5)),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Band karein')),
        ],
      ),
    );
  }

  Widget _row(String icon, String title, String sub, VoidCallback tap) => Tile(
        icon: icon,
        title: title,
        sub: sub,
        onTap: tap,
      );

  Future<void> _go(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    _refresh();
  }
}

/// ------------------------------------------------------------ COMPANIES
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});
  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Companies')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Repo.i.companies(),
          builder: (c, s) {
            if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            final list = s.data!;
            return ListView(padding: const EdgeInsets.all(14), children: [
              FilledButton(
                onPressed: () => _form(),
                child: const Text('+ Add Company'),
              ),
              const SizedBox(height: 14),
              if (list.isEmpty)
                const Empty('🏢', 'Koi company nahi',
                    sub: 'RNFi, Paynearby jaisi companies add karein')
              else
                ...list.map((x) => Tile(
                      icon: '🏢',
                      title: '${x['name']}',
                      sub: '${x['code']} · ${x['mode'] == 'auto' ? 'Auto mode' : 'Manual mode'}\n'
                          'Low alert below ${money(numOf(x['low_limit']))}',
                      amount: x['mode'] == 'auto' ? 'AUTO' : 'MANUAL',
                      amountColor: x['mode'] == 'auto' ? C.accent : C.pink,
                      onMenu: () async {
                        final r = await rowMenu(context, '${x['name']}');
                        if (r == 'edit' && mounted) {
                          _form(x);
                        } else if (r == 'delete' && mounted) {
                          // Guard: pehle IDs/banks hatane padenge, warna
                          // CASCADE chup-chaap saara data uda deta tha.
                          if (await confirm(context, 'Delete company?',
                              '${x['name']} — sirf tab hatega jab iski koi ID '
                              'aur bank na ho.')) {
                            final err = await Repo.i.deleteCompany(x['id'] as int);
                            if (!mounted) return;
                            if (err != null) {
                              toast(context, err, bg: C.error);
                            } else {
                              toast(context, 'Company delete', bg: C.warning);
                              setState(() {});
                            }
                          }
                        }
                      },
                    )),
            ]);
          },
        ),
      );

  Future<void> _form([Map<String, Object?>? e]) async {
    final name = TextEditingController(text: '${e?['name'] ?? ''}');
    final code = TextEditingController(text: '${e?['code'] ?? ''}');
    final phone = TextEditingController(text: '${e?['phone'] ?? ''}');
    final limit = TextEditingController(text: '${e?['low_limit'] ?? 40000}');
    var mode = '${e?['mode'] ?? 'manual'}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(e == null ? 'Add Company' : 'Edit Company'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              F(name, 'Company Name *'),
              F(code, 'Code *', hint: 'RNFI'),
              F(phone, 'Support Number'),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Calculation Mode',
                    style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 7, children: [
                for (final m in [
                  ['auto', '⚡ Auto'],
                  ['manual', '✋ Manual']
                ])
                  ChoiceChip(
                    label: Text(m[1], style: const TextStyle(fontSize: 12)),
                    selected: mode == m[0],
                    onSelected: (_) => setD(() => mode = m[0]),
                  ),
              ]),
              const SizedBox(height: 12),
              F(limit, 'Low Balance Alert Below', type: TextInputType.number),
              const Note('Auto — RNFi jaisi, app khud payout nikalta hai.\n'
                  'Manual — raat ko aap payout feed karte hain.'),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    // Validation ab Repo mein hai — duplicate code wagairah wahin check hota hai.
    final err = await Repo.i.saveCompany(
      id: e?['id'] as int?,
      name: name.text,
      code: code.text,
      mode: mode,
      phone: phone.text,
      lowLimit: parseD(limit),
    );
    if (!mounted) return;
    if (err != null) {
      toast(context, err, bg: C.error);
    } else {
      toast(context, e == null ? 'Company add ho gayi' : 'Company update ho gayi');
      setState(() {});
    }
  }
}

/// ------------------------------------------------------------- ACCOUNTS
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});
  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Company IDs')),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: Repo.i.accounts(),
          builder: (c, s) {
            if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());
            return ListView(padding: const EdgeInsets.all(14), children: [
              FilledButton(onPressed: () => _form(), child: const Text('+ Add Company ID')),
              const SizedBox(height: 12),
              const Note('Ek company mein kai ID ho sakti hain — jaise RNFi mein '
                  'Distributor ID (auto mode, fund nahi) aur Retailer ID (shop, saara fund).'),
              if (s.data!.isEmpty)
                const Empty('🆔', 'Koi ID nahi')
              else
                ...s.data!.map((a) => FutureBuilder<double>(
                      future: Repo.i.wallet(a['id'] as int),
                      builder: (c2, w) => Tile(
                        icon: a['type'] == 'distributor' ? '🤖' : '🏪',
                        color: a['type'] == 'distributor' ? C.purple : C.accent,
                        edge: a['type'] == 'distributor' ? C.purple : C.accent,
                        title: '${a['label']}',
                        sub: '${a['company']} · ${a['id_no']}\n'
                            '${a['fundable'] == 1 ? '✅ Fund deposit' : '⛔ Fund nahi'}'
                            '${a['funds_retailers'] == 1 ? '  ·  🤝 Retailer funding' : ''}',
                        amount: money(w.data ?? 0),
                        onMenu: () async {
                          final r = await rowMenu(context, '${a['label']}');
                          if (r == 'edit' && mounted) {
                            _form(a);
                          } else if (r == 'delete' && mounted) {
                            // Guard: entries hain to delete block — hisaab
                            // kharab na ho.
                            if (await confirm(context, 'Delete ID?',
                                '${a['label']} — sirf tab hatega jab iski koi '
                                'entry na ho.')) {
                              final err = await Repo.i.deleteAccount(a['id'] as int);
                              if (!mounted) return;
                              if (err != null) {
                                toast(context, err, bg: C.error);
                              } else {
                                toast(context, 'Company ID delete', bg: C.warning);
                                setState(() {});
                              }
                            }
                          }
                        },
                      ),
                    )),
            ]);
          },
        ),
      );

  Future<void> _form([Map<String, Object?>? e]) async {
    final comps = await Repo.i.companies();
    if (comps.isEmpty) {
      if (mounted) toast(context, 'Pehle company add karein', bg: C.warning);
      return;
    }
    if (!mounted) return;

    final label = TextEditingController(text: '${e?['label'] ?? ''}');
    final idno = TextEditingController(text: '${e?['id_no'] ?? ''}');
    final opening = TextEditingController(text: '${e?['opening'] ?? 0}');
    var cid = e?['company_id'] as int? ?? comps.first['id'] as int;
    var type = '${e?['type'] ?? 'retailer'}';
    // Fund hota hai ya nahi -- ye ab ID type se alag hai.
    // Kisi company mein Distributor ID mein bhi fund hota hai (jaise A2Z),
    // kisi mein nahi (jaise RNFi). Isliye user khud chunta hai.
    var fundable = e == null ? true : (e['fundable'] == 1);
    // Distributor ID hai to: kya isse retailers ko funding dete hain?
    var fundsRetailers = e != null && e['funds_retailers'] == 1;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(e == null ? 'Add Company ID' : 'Edit Company ID'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Company',
                  contentPadding: EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: cid,
                    isExpanded: true,
                    isDense: true,
                    items: comps
                        .map((x) => DropdownMenuItem(
                            value: x['id'] as int, child: Text('${x['name']}')))
                        .toList(),
                    onChanged: (v) => setD(() => cid = v!),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              F(label, 'ID ka naam *', hint: 'RNFi Retailer ID (Shop)'),
              F(idno, 'ID Number *', hint: 'RET-55821'),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('ID Type',
                    style: TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 7, children: [
                for (final t in [
                  ['retailer', '🏪 Retailer (Shop)'],
                  ['distributor', '🤖 Distributor']
                ])
                  ChoiceChip(
                    label: Text(t[1], style: const TextStyle(fontSize: 11.5)),
                    selected: type == t[0],
                    onSelected: (_) => setD(() => type = t[0]),
                  ),
              ]),
              const SizedBox(height: 12),
              // Fund switch -- ID type se alag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                decoration: BoxDecoration(
                  color: fundable ? const Color(0xFFF0F7F4) : const Color(0xFFF7F7F7),
                  border: Border.all(
                      color: fundable ? const Color(0xFFBFE3D3) : C.divider),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SwitchListTile(
                  value: fundable,
                  onChanged: (v) => setD(() => fundable = v),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                      fundable ? '✅ Is ID mein fund hota hai' : '⛔ Is ID mein fund nahi hota',
                      style: const TextStyle(
                          fontSize: 12.5, fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    fundable
                        ? 'Deposit, CMS, Shop entries mein ye ID dikhegi'
                        : 'Sirf profit entry hogi (auto-mode retailers wali)',
                    style: const TextStyle(fontSize: 10.5),
                  ),
                ),
              ),
              // ---- Retailer funding sawaal — sirf Distributor ID par ----
              if (type == 'distributor') ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                  decoration: BoxDecoration(
                    color: fundsRetailers
                        ? const Color(0xFFF3F0FA)
                        : const Color(0xFFF7F7F7),
                    border: Border.all(
                        color: fundsRetailers ? const Color(0xFFCFC2EC) : C.divider),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SwitchListTile(
                    value: fundsRetailers,
                    onChanged: (v) => setD(() => fundsRetailers = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kya aap retailer ko funding karte hain is ID se?',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      fundsRetailers
                          ? '✅ Haan — Retailers tab mein ye ID aayegi. '
                              'Fund dene par wallet minus, wapsi par plus.'
                          : 'Nahi — sirf apna kaam is ID se hota hai',
                      style: const TextStyle(fontSize: 10.5),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              F(opening, 'Opening Balance', type: TextInputType.number),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final err = await Repo.i.saveAccount(
      id: e?['id'] as int?,
      companyId: cid,
      label: label.text,
      idNo: idno.text,
      type: type,
      fundable: fundable,
      opening: parseD(opening),
      fundsRetailers: fundsRetailers,
    );
    if (!mounted) return;
    if (err != null) {
      toast(context, err, bg: C.error);
    } else {
      toast(context, e == null ? 'ID add ho gayi' : 'ID update ho gayi');
      setState(() {});
    }
  }
}

/// ---------------------------------------------------------------- BANKS
/// Bank manager — Add / Edit / Delete, company-wise grouping,
/// aur do tarah ka deposit charge: FIXED (₹ per txn) ya PERCENT (% of amount).
class BanksScreen extends StatefulWidget {
  const BanksScreen({super.key});
  @override
  State<BanksScreen> createState() => _BanksScreenState();
}

class _BanksScreenState extends State<BanksScreen> {
  Future<Map<String, dynamic>> _load() async => {
        'banks': await Repo.i.banks(),
        'comps': await Repo.i.companies(),
        'usage': await Repo.i.allBankUsage(),
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Banks & Charges')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _form(),
          backgroundColor: C.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('Naya Bank', style: TextStyle(color: Colors.white)),
        ),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _load(),
          builder: (c, s) {
            if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) return const Center(child: CircularProgressIndicator());

            final banks = s.data!['banks'] as List<Map<String, Object?>>;
            final comps = s.data!['comps'] as List<Map<String, Object?>>;
            final usage = s.data!['usage'] as Map<int, Map<String, double>>;

            var totalLoss = 0.0;
            for (final u in usage.values) {
              totalLoss += u['charge'] ?? 0;
            }

            final kids = <Widget>[
              const Note('Har bank kis company ka hai wo chunein. Deposit charge '
                  'do tarah ka hota hai — FIXED (₹ per transaction) ya '
                  'PERCENT (% of amount). Ye charge aapka LOSS hai, net profit se minus hota hai.'),
            ];

            if (comps.isEmpty) {
              kids.add(const Empty('🏢', 'Pehle company add karein',
                  sub: 'Bank hamesha kisi company se juda hota hai'));
            } else {
              for (final cm in comps) {
                final cid = cm['id'] as int;
                final list = banks.where((b) => b['company_id'] == cid).toList();
                kids.add(Padding(
                  padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
                  child: Text('${cm['name']} (${list.length})',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
                ));
                if (list.isEmpty) {
                  kids.add(AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const Expanded(
                        child: Text('Is company ka koi bank nahi',
                            style: TextStyle(fontSize: 11.5, color: C.muted)),
                      ),
                      TextButton(
                        onPressed: () => _form(null, cid),
                        child: const Text('+ Add', style: TextStyle(fontSize: 11.5)),
                      ),
                    ]),
                  ));
                } else {
                  for (final b in list) {
                    kids.add(_bankCard(b, usage[b['id'] as int]));
                  }
                }
              }
            }

            if (totalLoss > 0) {
              kids.add(const SizedBox(height: 14));
              kids.add(AppCard(
                color: const Color(0xFFFDECEC),
                padding: const EdgeInsets.all(13),
                child: Row2('⚠️ Kul bank charge loss', '−${money(totalLoss)}',
                    bold: true, color: C.error),
              ));
            }
            kids.add(const SizedBox(height: 80));

            return ListView(padding: const EdgeInsets.all(14), children: kids);
          },
        ),
      );

  Widget _bankCard(Map<String, Object?> b, Map<String, double>? u) {
    final rate = numOf(b['chg_rate']);
    final pct = b['chg_mode'] == 'percent';
    final free = rate <= 0;
    final col = free ? C.accent : C.error;
    final rule = free
        ? 'Koi charge nahi'
        : (pct ? '$rate% of amount' : '₹$rate per transaction');
    final demo = free ? 0.0 : (pct ? r2(10000 * rate / 100) : r2(rate));
    final cnt = (u?['count'] ?? 0).toInt();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        leftEdge: Container(width: 4, color: col),
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🏦', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${b['bank']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                    'A/c ${b['acno']}'
                    '${'${b['ifsc'] ?? ''}'.isEmpty ? '' : ' · ${b['ifsc']}'}',
                    style: const TextStyle(fontSize: 9.5, color: C.muted)),
              ]),
            ),
            Badge2(free ? 'FREE' : (pct ? 'PERCENT' : 'FIXED'), col),
            const SizedBox(width: 4),
            InkWell(
              onTap: () => _menu(b),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.more_vert, size: 18, color: C.muted),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row2('Charge rule', rule, color: col),
          if (!free) Row2('₹10,000 deposit par', '−${money(demo)}', small: true, color: C.error),
          if (cnt > 0) ...[
            Row2('Deposits ($cnt)', money(u!['volume']), small: true),
            Row2('Total charge loss', '−${money(u['charge'])}', small: true, color: C.error),
          ],
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _form(b),
                child: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => _delete(b),
                style: OutlinedButton.styleFrom(
                    foregroundColor: C.error, side: const BorderSide(color: C.error)),
                child: const Text('Delete', style: TextStyle(fontSize: 12)),
              ),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _menu(Map<String, Object?> b) async {
    final x = await rowMenu(context, '${b['bank']}');
    if (!mounted) return;
    if (x == 'edit') {
      _form(b);
    } else if (x == 'delete') {
      _delete(b);
    }
  }

  Future<void> _delete(Map<String, Object?> b) async {
    final u = await Repo.i.bankUsage(b['id'] as int);
    if (!mounted) return;
    final cnt = (u['count'] ?? 0).toInt();
    if (cnt > 0) {
      toast(context, 'Is bank ki $cnt deposit entries hain — delete nahi hoga',
          bg: C.error);
      return;
    }
    if (!await confirm(context, 'Delete bank?', '${b['bank']} — A/c ${b['acno']}')) return;
    final err = await Repo.i.deleteBank(b['id'] as int);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, bg: C.error);
    } else {
      toast(context, 'Bank delete ho gaya', bg: C.warning);
      setState(() {});
    }
  }

  Future<void> _form([Map<String, Object?>? e, int? preCid]) async {
    final comps = await Repo.i.companies();
    if (!mounted) return;
    if (comps.isEmpty) {
      toast(context, 'Pehle company add karein', bg: C.warning);
      return;
    }

    final bank = TextEditingController(text: '${e?['bank'] ?? ''}');
    final holder = TextEditingController(text: '${e?['holder'] ?? ''}');
    final acno = TextEditingController(text: '${e?['acno'] ?? ''}');
    final ifsc = TextEditingController(text: '${e?['ifsc'] ?? ''}');
    final upi = TextEditingController(text: '${e?['upi'] ?? ''}');
    final chg = TextEditingController(
        text: e == null ? '' : '${numOf(e['chg_rate'])}');
    var cid = e?['company_id'] as int? ?? preCid ?? comps.first['id'] as int;
    var cmode = '${e?['chg_mode'] ?? 'fixed'}';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final rate = double.tryParse(chg.text.trim()) ?? 0;
          final pct = cmode == 'percent';
          return AlertDialog(
            title: Text(e == null ? '➕ Naya Bank' : '✏️ Edit Bank'),
            content: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Kis company ka bank? *',
                      style: TextStyle(fontSize: 11.5, color: C.muted)),
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final cm in comps)
                    ChoiceChip(
                      label: Text('${cm['name']}', style: const TextStyle(fontSize: 11.5)),
                      selected: cid == cm['id'],
                      onSelected: (_) => setD(() => cid = cm['id'] as int),
                    ),
                ]),
                const SizedBox(height: 14),
                F(bank, 'Bank ka naam *', hint: 'Indian Bank'),
                F(holder, 'Account holder', hint: 'Digitronic Services'),
                F(acno, 'Account number *', hint: '50100234'),
                F(ifsc, 'IFSC code', hint: 'IDIB000K123'),
                F(upi, 'UPI ID', hint: 'digitronic@upi'),
                const Divider(),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Deposit Charge Rule',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: C.error)),
                ),
                const SizedBox(height: 8),
                Wrap(spacing: 7, children: [
                  for (final m in [
                    ['fixed', '₹ Fixed per txn'],
                    ['percent', '% Percentage']
                  ])
                    ChoiceChip(
                      label: Text(m[1], style: const TextStyle(fontSize: 11.5)),
                      selected: cmode == m[0],
                      onSelected: (_) => setD(() => cmode = m[0]),
                    ),
                ]),
                const SizedBox(height: 12),
                F(chg, pct ? 'Charge % (amount ka)' : 'Charge ₹ per transaction',
                    type: TextInputType.number,
                    hint: pct ? '0.5' : '12',
                    onChanged: (_) => setD(() {})),
                if (rate > 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(9)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Charge example',
                          style: TextStyle(fontSize: 10.5, color: C.muted)),
                      const SizedBox(height: 4),
                      for (final a in [5000.0, 50000.0, 200000.0])
                        Row2('₹${a.toInt()} deposit',
                            '−${money(pct ? r2(a * rate / 100) : r2(rate))}',
                            small: true, color: C.error),
                      const SizedBox(height: 4),
                      const Text('Ye aapka LOSS hai — net profit se minus hoga',
                          style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w700, color: C.error)),
                    ]),
                  )
                else
                  const Note('0 rakhein to koi charge nahi lagega (jaise HDFC free deposit).'),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
            ],
          );
        },
      ),
    );

    if (ok != true) return;
    final err = await Repo.i.saveBank(
      id: e?['id'] as int?,
      companyId: cid,
      bank: bank.text,
      acno: acno.text,
      holder: holder.text,
      ifsc: ifsc.text,
      upi: upi.text,
      chgMode: cmode,
      chgRate: parseD(chg),
    );
    if (!mounted) return;
    if (err != null) {
      toast(context, err, bg: C.error);
    } else {
      toast(context, e == null ? 'Bank add ho gaya' : 'Bank update ho gaya');
      setState(() {});
    }
  }
}

/// ---------------------------------------------------------------- RATES/// -------------------------------------------------- SERVICE MANAGER
/// Services add / edit / delete / order badalna
class RatesScreen extends StatefulWidget {
  const RatesScreen({super.key});
  @override
  State<RatesScreen> createState() => _RatesScreenState();
}

class _RatesScreenState extends State<RatesScreen> {
  Future<List<Map<String, Object?>>> _load() async {
    final list = await Repo.i.services();
    // har service ki entry count bhi chahiye (delete warning ke liye)
    final out = <Map<String, Object?>>[];
    for (final s in list) {
      final n = await Repo.i.serviceEntryCount('${s['code']}');
      out.add({...s, '_count': n});
    }
    return out;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Services & Rates')),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: C.primary,
          foregroundColor: Colors.white,
          onPressed: () => _form(),
          icon: const Icon(Icons.add),
          label: const Text('Nayi Service'),
        ),
        body: FutureBuilder<List<Map<String, Object?>>>(
          future: _load(),
          builder: (c, s) {
            if (s.hasError) return ErrBox(s.error!);
            if (!s.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final list = s.data!;
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
              children: [
                const Note(
                  'Apni services yahan banayein. Ek baar rate feed karein — '
                  'phir har entry auto calculate hogi.\n\n'
                  'Cash OUT = customer ko cash dete hain (AEPS, UPI cashout)\n'
                  'Cash IN = customer se cash lete hain (Transfer, Recharge)',
                ),
                if (list.isEmpty)
                  const Empty('⚙️', 'Koi service nahi',
                      sub: 'Neeche + button se pehli service banayein')
                else
                  ...list.asMap().entries.map((e) {
                    final i = e.key;
                    final x = e.value;
                    return _card(x, i, list.length);
                  }),
              ],
            );
          },
        ),
      );

  Widget _card(Map<String, Object?> x, int idx, int total) {
    final out = x['direction'] == 'cashout';
    final col = C.hex('${x['color']}');
    final cp = numOf(x['charge_pct']);
    final rt = numOf(x['round_to']);
    final count = x['_count'] as int? ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: col, width: 4)),
        boxShadow: const [
          BoxShadow(color: Color(0x140D2A5C), blurRadius: 3, offset: Offset(0, 1))
        ],
      ),
      padding: const EdgeInsets.all(13),
      child: Column(children: [
        Row(children: [
          Text('${x['icon']}', style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${x['name']}',
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w700)),
                  Text('${x['code']} · $count entries',
                      style: const TextStyle(fontSize: 10, color: C.muted)),
                ]),
          ),
          Badge2(out ? 'CASH OUT' : 'CASH IN', out ? C.teal : C.pink),
        ]),
        const SizedBox(height: 8),

        // Company se milne wala
        if (numOf(x['payout']) > 0) ...[
          Row2('Company payout / txn', '₹${numOf(x['payout'])}', bold: true),
          if (numOf(x['tds_pct']) > 0)
            Row2('TDS', '${numOf(x['tds_pct'])}%', bold: true),
        ],
        // Customer se apna extra
        if (numOf(x['comm_pct']) > 0)
          Row2('Extra commission', '${numOf(x['comm_pct'])}%', bold: true),
        if (cp > 0) ...[
          Row2('Round-off charge', '$cp% round ₹$rt', bold: true),
          Row2('₹1800 →', '₹${customerCharge(1800, cp, rt).toStringAsFixed(0)}',
              small: true),
          Row2('₹10000 →', '₹${customerCharge(10000, cp, rt).toStringAsFixed(0)}',
              small: true),
        ],
        if (numOf(x['payout']) == 0 &&
            numOf(x['comm_pct']) == 0 &&
            cp == 0)
          const Row2('⚠️ Koi rate set nahi', 'Edit karke bharein',
              small: true),

        const SizedBox(height: 10),
        Row(children: [
          // order badalne ke buttons
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: idx == 0 ? C.divider : C.muted,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: idx == 0
                ? null
                : () async {
                    await Repo.i.moveService(x['id'] as int, -1);
                    setState(() {});
                  },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            color: idx == total - 1 ? C.divider : C.muted,
            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
            padding: EdgeInsets.zero,
            onPressed: idx == total - 1
                ? null
                : () async {
                    await Repo.i.moveService(x['id'] as int, 1);
                    setState(() {});
                  },
          ),
          const Spacer(),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(70, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => _form(x),
            child: const Text('Edit', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 7),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: C.error,
                side: const BorderSide(color: C.error),
                minimumSize: const Size(70, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => _delete(x),
            child: const Text('Delete', style: TextStyle(fontSize: 12)),
          ),
        ]),
      ]),
    );
  }

  Future<void> _delete(Map<String, Object?> x) async {
    final count = x['_count'] as int? ?? 0;
    if (count > 0) {
      showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete nahi ho sakti'),
          content: Text(
            '"${x['name']}" ki $count entries hain.\n\n'
            'Delete karne se purana hisaab toot jaayega. '
            'Agar ye service ab nahi chahiye to bas ise use mat karein — '
            'purana data surakshit rahega.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Theek hai'))
          ],
        ),
      );
      return;
    }
    final ok = await confirm(context, 'Delete service?',
        '"${x['name']}" hat jaayegi. Koi entry nahi hai to safe hai.');
    if (!ok) return;
    final err = await Repo.i.deleteService(x['id'] as int);
    if (!mounted) return;
    if (err != null) {
      toast(context, err, bg: C.error);
    } else {
      setState(() {});
      toast(context, 'Service delete ho gayi', bg: C.warning);
    }
  }

  Future<void> _form([Map<String, Object?>? e]) async {
    final isNew = e == null;
    final name = TextEditingController(text: '${e?['name'] ?? ''}');
    final code = TextEditingController(text: '${e?['code'] ?? ''}');
    final payout = TextEditingController(text: '${numOf(e?['payout'])}');
    final tds = TextEditingController(text: '${numOf(e?['tds_pct'])}');
    final chg = TextEditingController(text: '${numOf(e?['charge_pct'])}');
    final round =
        TextEditingController(text: '${e == null ? 10 : numOf(e['round_to'])}');
    final comm = TextEditingController(text: '${numOf(e?['comm_pct'])}');
    var dir = '${e?['direction'] ?? 'cashout'}';
    var icon = '${e?['icon'] ?? '💼'}';
    var color = '${e?['color'] ?? '0D2A5C'}';

    const icons = ['👆', '📱', '➡️', '📞', '💳', '🏧', '🎫', '⚡', '🎬', '📺',
                   '🚌', '✈️', '🛡️', '💊', '📦', '💼'];
    const colors = {
      '0D2A5C': 'Navy', '17A673': 'Green', '0E8F8F': 'Teal',
      '1B4B9B': 'Blue', '6B4FBB': 'Purple', 'C2497E': 'Pink',
      'F08C00': 'Orange', 'D32F2F': 'Red',
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          insetPadding: const EdgeInsets.all(16),
          title: Text(isNew ? 'Nayi Service' : 'Edit ${e['name']}'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                F(name, 'Service ka naam *', hint: 'e.g. DMT Money Transfer'),
                if (isNew)
                  F(code, 'Short code *', hint: 'e.g. dmt (sirf angrezi akshar)')
                else
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Code'),
                      child: Text('${e['code']}',
                          style: const TextStyle(
                              fontSize: 14, color: C.muted)),
                    ),
                  ),

                // Direction
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Paisa kis taraf?',
                      style: TextStyle(
                          fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Column(children: [
                  RadioListTile<String>(
                    value: 'cashout',
                    groupValue: dir,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cash OUT — customer ko cash dete hain',
                        style: TextStyle(fontSize: 12)),
                    subtitle: const Text('Counter cash ghatega, wallet badhega',
                        style: TextStyle(fontSize: 10)),
                    onChanged: (v) => setD(() => dir = v!),
                  ),
                  RadioListTile<String>(
                    value: 'cashin',
                    groupValue: dir,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Cash IN — customer se cash lete hain',
                        style: TextStyle(fontSize: 12)),
                    subtitle: const Text('Counter cash badhega, wallet ghatega',
                        style: TextStyle(fontSize: 10)),
                    onChanged: (v) => setD(() => dir = v!),
                  ),
                ]),
                const SizedBox(height: 10),

                // Icon
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Icon chunein',
                      style: TextStyle(
                          fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: icons
                      .map((i) => GestureDetector(
                            onTap: () => setD(() => icon = i),
                            child: Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: icon == i
                                    ? C.fade(C.primary, .12)
                                    : Colors.white,
                                border: Border.all(
                                    color: icon == i ? C.primary : C.divider,
                                    width: icon == i ? 2 : 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(i, style: const TextStyle(fontSize: 17)),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // Colour
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Colour chunein',
                      style: TextStyle(
                          fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: colors.keys
                      .map((h) => GestureDetector(
                            onTap: () => setD(() => color = h),
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: C.hex(h),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: color == h ? C.text : Colors.transparent,
                                    width: 3),
                              ),
                              child: color == h
                                  ? const Icon(Icons.check,
                                      color: Colors.white, size: 18)
                                  : null,
                            ),
                          ))
                      .toList(),
                ),
                const Divider(height: 24),

                // ---- Company se kya milta hai ----
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Company se kya milta hai',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: C.primary)),
                ),
                const SizedBox(height: 8),
                F(payout, 'Company payout per txn (₹)',
                    type: TextInputType.number),
                F(tds, 'TDS % (payout par)', type: TextInputType.number),
                const Note('DMT, AEPS, BBPS — sabhi mein company payout deti hai. '
                    'Na mile to 0 rakhein.'),

                const Divider(height: 20),

                // ---- Customer se kya lete hain ----
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Customer se apna extra',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: C.accent)),
                ),
                const SizedBox(height: 8),
                F(comm, 'Extra commission % (seedha %)',
                    type: TextInputType.number),
                F(chg, 'Ya round-off charge %', type: TextInputType.number),
                F(round, 'Round to nearest (₹)', type: TextInputType.number),
                const Note('Dono bhar sakte hain — dono jud jaayenge.\n\n'
                    'Commission 2% = ₹10000 par ₹200 (seedha)\n'
                    'Round-off 1% + ₹10 = ₹1800 par ₹20 (upar round)'),
              ]),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    if (name.text.trim().isEmpty) {
      if (mounted) toast(context, 'Naam zaroori hai', bg: C.error);
      return;
    }

    if (isNew) {
      if (code.text.trim().isEmpty) {
        if (mounted) toast(context, 'Code zaroori hai', bg: C.error);
        return;
      }
      final err = await Repo.i.addService(
        code: code.text,
        name: name.text,
        direction: dir,
        icon: icon,
        color: color,
        payout: parseD(payout),
        tdsPct: parseD(tds),
        chargePct: parseD(chg),
        roundTo: parseD(round),
        commPct: parseD(comm),
      );
      if (!mounted) return;
      if (err != null) {
        toast(context, err, bg: C.error);
        return;
      }
      setState(() {});
      toast(context, 'Service add ho gayi');
    } else {
      await Repo.i.edit('services', e['id'] as int, {
        'name': name.text.trim(),
        'direction': dir,
        'icon': icon,
        'color': color,
        'payout': parseD(payout),
        'tds_pct': parseD(tds),
        'charge_pct': parseD(chg),
        'round_to': parseD(round) <= 0 ? 1 : parseD(round),
        'comm_pct': parseD(comm),
      });
      if (!mounted) return;
      setState(() {});
      toast(context, 'Rate update ho gaya');
    }
  }
}

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});
  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _old = TextEditingController();
  final _new = TextEditingController();
  final _c = TextEditingController();
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change PIN')),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          _pf(_old, 'Current PIN'),
          _pf(_new, 'New PIN (4 ya 6 digit)'),
          _pf(_c, 'Confirm New PIN'),
          const Note('PIN sirf aapke phone mein encrypted save hota hai. '
              'Bhool gaye to reset nahi ho sakta — kahin likh kar rakhein.'),
          FilledButton(
            onPressed: _busy ? null : () async {
              final n = _new.text.trim();
              if (n.length != 4 && n.length != 6) {
                return toast(context, 'PIN 4 ya 6 digit ka ho', bg: C.error);
              }
              if (n != _c.text.trim()) {
                return toast(context, 'Naya PIN match nahi kar raha', bg: C.error);
              }
              setState(() => _busy = true);
              final ok = await PinService.change(_old.text.trim(), n);
              if (!mounted) return;
              setState(() => _busy = false);
              if (ok) {
                toast(context, 'PIN badal gaya');
                Navigator.pop(context);
              } else {
                toast(context, 'Current PIN galat hai', bg: C.error);
              }
            },
            child: Text(_busy ? 'Saving…' : 'Update PIN'),
          ),
        ]),
      );

  Widget _pf(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: label, counterText: ''),
        ),
      );
}

import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../data/repo.dart';
import '../logic/calc.dart';
import 'forms.dart';
import 'day_dialog.dart';

class DashboardTab extends StatefulWidget {
  final VoidCallback onChanged;
  const DashboardTab({super.key, required this.onChanged});
  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _r = Repo.i;

  Future<Map<String, dynamic>> _load() async {
    final d = todayStr();
    return {
      'profit': await _r.dayProfit(d),
      'wallet': await _r.totalWallet(),
      'cash': await _r.counterCash(),
      'tds': await _r.totalTds(d),
      'accounts': await _r.accounts(),
      'services': await _r.services(),
      'cmsVol': await _r.cmsVolume(d),
      'depTotal': await _r.depositTotal(d),
      'aeps': await _r.serviceTotals('aeps', d),
      'upi': await _r.serviceTotals('upi', d),
      'transfer': await _r.serviceTotals('upitransfer', d),
      'recharge': await _r.serviceTotals('recharge', d),
      'pending': await _r.pendingPayouts(),
      'hasOpen': await _r.hasSnap('open'),
      'hasClose': await _r.hasSnap('close'),
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
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        final pr = d['profit'] as DayProfit;
        final accounts = (d['accounts'] as List).cast<Map<String, Object?>>();
        final pending = (d['pending'] as List).cast<Map<String, Object?>>();

        return RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            children: [
              // Day start / close
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: d['hasOpen'] == true ? C.muted : C.warning,
                        minimumSize: const Size.fromHeight(42)),
                    onPressed: () async {
                      await showDayDialog(context, 'open');
                      _refresh();
                    },
                    icon: const Text('☀️', style: TextStyle(fontSize: 14)),
                    label: Text(d['hasOpen'] == true ? 'Day Started' : 'Day Start',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: d['hasClose'] == true ? C.muted : C.primary,
                        minimumSize: const Size.fromHeight(42)),
                    onPressed: () async {
                      await showDayDialog(context, 'close');
                      _refresh();
                    },
                    icon: const Text('🌙', style: TextStyle(fontSize: 14)),
                    label: Text(d['hasClose'] == true ? 'Day Closed' : 'Day Close',
                        style: const TextStyle(fontSize: 13)),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              // Net profit banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [C.primary, C.primaryLight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Text('Aaj ka NET PROFIT',
                        style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: C.fade(Colors.white, .18),
                          borderRadius: BorderRadius.circular(20)),
                      child: const Text('⚡ OFFLINE',
                          style: TextStyle(
                              color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(money(pr.net),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    _b('Wallet', sm(d['wallet'])),
                    _b('Cash', sm(d['cash'])),
                    _b('TDS', sm(d['tds'])),
                  ]),
                ]),
              ),

              // Profit breakup
              const Sec('Profit Breakup'),
              AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: Column(children: [
                    _pr('💵 CMS', pr.cmsNet, true),
                    _pr('🏪 Shop services', pr.shopNet, true),
                    _pr('🤖 Distributor', pr.distProfit, true),
                    _pr('✋ Manual payouts', pr.manualNet, false),
                    const Divider(height: 14),
                    Row2('Gross income', money(pr.gross), bold: true),
                    Row2('− Bank deposit charges', '−${money(pr.depositCharges)}',
                        color: C.error),
                    const Divider(height: 14),
                    Row2('NET PROFIT', money(pr.net), bold: true, color: C.accent),
                  ]),
                ),
              ),

              if (pending.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC),
                      border: Border.all(color: const Color(0xFFF5D9A8)),
                      borderRadius: BorderRadius.circular(9)),
                  child: Row(children: [
                    const Text('⚠️', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Payout baaki: ${pending.map((e) => e['name']).join(', ')}',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ]),
                ),

              // Volume
              const Sec("Aaj ka Volume"),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.75,
                children: [
                  StatCard('💵', C.accent, sm(d['cmsVol']), 'CMS'),
                  StatCard('👆', C.teal, sm((d['aeps'] as Map)['vol']), 'AEPS'),
                  StatCard('📱', C.primaryLight, sm((d['upi'] as Map)['vol']), 'UPI Cashout'),
                  StatCard('➡️', C.purple, sm((d['transfer'] as Map)['vol']), 'UPI Transfer'),
                  StatCard('🏦', C.primary, sm(d['depTotal']), 'Deposit'),
                  StatCard('⚠️', C.error, sm(pr.depositCharges), 'Bank Charges'),
                ],
              ),

              // Quick add
              const Sec('Quick Add'),
              SizedBox(
                height: 84,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  _q('💵', 'CMS', C.accent, () => _open(const CmsForm())),
                  _q('👆', 'AEPS', C.teal, () => _open(const ShopForm(code: 'aeps'))),
                  _q('📱', 'UPI Out', C.primaryLight,
                      () => _open(const ShopForm(code: 'upi'))),
                  _q('➡️', 'Transfer', C.purple,
                      () => _open(const ShopForm(code: 'upitransfer'))),
                  _q('📞', 'Recharge', C.pink,
                      () => _open(const ShopForm(code: 'recharge'))),
                  _q('🏦', 'Deposit', C.primary, () => _open(const DepositForm())),
                  _q('✋', 'Payout', C.pink, () => _open(const PayoutForm())),
                  _q('💰', 'Float', C.warning, () => _open(const FloatForm())),
                ]),
              ),

              // Wallets
              const Sec('Company ID Wallets'),
              if (accounts.isEmpty)
                const Empty('🏢', 'Koi company ID nahi',
                    sub: 'More → Companies se add karein')
              else
                ...accounts.map((a) => FutureBuilder<double>(
                      future: _r.wallet(a['id'] as int),
                      builder: (c, w) {
                        final bal = w.data ?? 0;
                        final isDist = a['type'] == 'distributor';
                        final auto = a['company_mode'] == 'auto';
                        final low = (a['low_limit'] as num).toDouble();
                        return Tile(
                          icon: isDist ? '🤖' : '🏪',
                          color: isDist ? C.purple : C.accent,
                          edge: isDist
                              ? C.purple
                              : (bal < low ? C.warning : C.accent),
                          title: '${a['label']}',
                          sub: '${a['company']} · ${a['id_no']}\n'
                              '${a['fundable'] == 1 ? 'Counter / CDM deposit' : 'Auto mode — no fund'}',
                          amount: money(bal),
                          amountSub: auto ? 'AUTO' : 'MANUAL',
                          amountColor: bal < low && !isDist ? C.warning : C.text,
                        );
                      },
                    )),
            ],
          ),
        );
      },
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
                    color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      );

  Widget _pr(String label, double v, bool auto) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(children: [
          Expanded(
            child: Row(children: [
              Flexible(child: Text(label, style: const TextStyle(fontSize: 12.5))),
              const SizedBox(width: 5),
              Badge2(auto ? 'AUTO' : 'MANUAL', auto ? C.accent : C.pink),
            ]),
          ),
          Text(money(v), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _q(String icon, String label, Color color, VoidCallback tap) => Padding(
        padding: const EdgeInsets.only(right: 9),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: tap,
          child: Container(
            width: 76,
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.fade(color, .5))),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(icon, style: const TextStyle(fontSize: 19)),
              const SizedBox(height: 5),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      );

  Future<void> _open(Widget form) async {
    final ok = await Navigator.push<bool>(
        context, MaterialPageRoute(builder: (_) => form, fullscreenDialog: true));
    if (ok == true) _refresh();
  }
}

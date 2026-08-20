import 'package:finfloat/logic/calc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Customer round-off charge (aapka rule)', () {
    test('₹1500 → ₹20', () => expect(customerCharge(1500, 1, 10), 20));
    test('₹1800 → ₹20', () => expect(customerCharge(1800, 1, 10), 20));
    test('₹10000 → ₹100', () => expect(customerCharge(10000, 1, 10), 100));
    test('₹1000 → ₹10', () => expect(customerCharge(1000, 1, 10), 10));
    test('₹2100 → ₹30 (21 upar round)', () => expect(customerCharge(2100, 1, 10), 30));
    test('UPI transfer 1.5%: ₹10000 → ₹150',
        () => expect(customerCharge(10000, 1.5, 10), 150));
    test('UPI transfer 1.5%: ₹5000 → ₹80 (75 upar round)',
        () => expect(customerCharge(5000, 1.5, 10), 80));
    test('zero amount → 0', () => expect(customerCharge(0, 1, 10), 0));
  });

  group('Bank deposit charge (LOSS)', () {
    test('Indian Bank ₹12 fixed, amount se farak nahi', () {
      expect(depositCharge('fixed', 12, 80000), 12);
      expect(depositCharge('fixed', 12, 5000), 12);
    });
    test('Axis 0.5% of ₹25000 = ₹125',
        () => expect(depositCharge('percent', 0.5, 25000), 125));
    test('rate 0 → koi charge nahi', () {
      expect(depositCharge('fixed', 0, 50000), 0);
      expect(depositCharge('percent', 0, 50000), 0);
    });
  });

  group('CMS payout', () {
    test('percent party: 0.35% of ₹45000', () {
      final r = cmsCalc(mode: 'percent', rate: 0.35, tdsPct: 5, amount: 45000);
      expect(r.payout, 157.5);
      expect(r.tds, 7.88);
      expect(r.net, 149.62);
    });
    test('fixed party: ₹12 per pickup', () {
      final r = cmsCalc(mode: 'fixed', rate: 12, tdsPct: 5, amount: 18000);
      expect(r.payout, 12);
      expect(r.tds, 0.6);
      expect(r.net, 11.4);
    });
    test('TDS 0% → net = payout', () {
      final r = cmsCalc(mode: 'fixed', rate: 15, tdsPct: 0, amount: 9000);
      expect(r.net, 15);
    });
  });

  group('Shop services — paisa kis taraf jaata hai', () {
    test('AEPS ₹1800: payout 5, charge 20, tds .25 → net 24.75', () {
      final r = shopCalc(
          direction: 'cashout', payoutPerTxn: 5, tdsPct: 5, chargePct: 1,
          roundTo: 10, commPct: 0, amount: 1800, count: 1);
      expect(r.payout, 5);
      expect(r.charge, 20);
      expect(r.tds, 0.25);
      expect(r.net, 24.75);
    });
    test('AEPS: cash ghatta, wallet badhta', () {
      final r = shopCalc(
          direction: 'cashout', payoutPerTxn: 5, tdsPct: 5, chargePct: 1,
          roundTo: 10, commPct: 0, amount: 10000, count: 1);
      expect(r.cashDelta, -10000);
      expect(r.walletDelta, 10000);
    });
    test('UPI Transfer: cash badhta, wallet ghatta', () {
      final r = shopCalc(
          direction: 'cashin', payoutPerTxn: 0, tdsPct: 0, chargePct: 1.5,
          roundTo: 10, commPct: 0, amount: 10000, count: 1);
      expect(r.charge, 150);
      expect(r.net, 150);
      expect(r.cashDelta, 10000);
      expect(r.walletDelta, -10000);
    });
    test('Recharge 2.5% commission', () {
      final r = shopCalc(
          direction: 'cashin', payoutPerTxn: 0, tdsPct: 0, chargePct: 0,
          roundTo: 10, commPct: 2.5, amount: 2400, count: 8);
      // NOTE: customer se liya commission `charge` mein jaata hai.
      // `payout` sirf wo hai jo COMPANY deti hai (aur uspar TDS katta hai).
      // Recharge mein company kuch nahi deti, isliye payout = 0.
      expect(r.payout, 0);
      expect(r.charge, 60);
      expect(r.net, 60);
      expect(r.cashDelta, 2400);
    });
    test('multi-txn payout multiply hota hai', () {
      final r = shopCalc(
          direction: 'cashout', payoutPerTxn: 5, tdsPct: 5, chargePct: 1,
          roundTo: 10, commPct: 0, amount: 5000, count: 3);
      expect(r.payout, 15);
    });
  });

  group('Manual payout (editable)', () {
    test('payout 340 − tds 17 + extra 120 = 443',
        () => expect(manualNet(payout: 340, tds: 17, extra: 120), 443));
    test('sirf extra income', () => expect(manualNet(payout: 0, tds: 0, extra: 250), 250));
  });

  group('Net profit = gross − bank charges', () {
    test('charges profit se minus hote hain', () {
      const p = DayProfit(
          cmsNet: 329.17, shopNet: 268.05, manualNet: 443,
          distProfit: 520, depositCharges: 137);
      expect(p.gross, 1560.22);
      expect(p.net, 1423.22);
      expect(p.net < p.gross, true);
    });
    test('koi charge nahi → net == gross', () {
      const p = DayProfit(cmsNet: 100, shopNet: 50);
      expect(p.net, p.gross);
    });
  });
}

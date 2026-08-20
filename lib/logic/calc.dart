/// FinFloat Pro — Calculation Engine
///
/// Yahan saara paisa ka hisaab hota hai. Ye file pure Dart hai (koi Flutter
/// import nahi) taaki iske tests bina emulator ke chal sakein.
///
/// Business rules (aapke bataye hue):
///  • CMS pickup   → Counter Cash +, Wallet −  (payout − TDS = income)
///  • AEPS / UPI cashout → Counter Cash −, Wallet +  (payout + charge − TDS)
///  • UPI Transfer / Recharge → Counter Cash +, Wallet −
///  • Bank deposit → Counter Cash −, Wallet +  (charge = LOSS)
///  • Net Profit = Gross income − Bank deposit charges
library;

double r2(num v) => (v * 100).round() / 100;

// ---------------------------------------------------------------- charges
/// Customer se liya jaane wala round-off charge.
/// Aapka rule: ₹1500→₹20, ₹1800→₹20, ₹10000→₹100 (1%, ₹10 ke multiple mein)
double customerCharge(double amount, double pct, double roundTo) {
  if (amount <= 0 || pct <= 0) return 0;
  final step = roundTo <= 0 ? 1.0 : roundTo;
  return (amount * pct / 100 / step).ceil() * step;
}

/// Bank deposit charge — ye aapka LOSS hai.
/// fixed  → har transaction par utne rupaye (Indian Bank ₹12)
/// percent→ amount ka % (Axis 0.5%)
double depositCharge(String mode, double rate, double amount) {
  if (rate <= 0) return 0;
  return mode == 'percent' ? r2(amount * rate / 100) : r2(rate);
}

// ------------------------------------------------------------------- CMS
class CmsResult {
  final double payout, tds, net;
  const CmsResult(this.payout, this.tds, this.net);
}

/// CMS party ka rate ek baar feed hota hai, phir har pickup auto.
CmsResult cmsCalc({
  required String mode, // 'percent' | 'fixed'
  required double rate,
  required double tdsPct,
  required double amount,
}) {
  final payout = r2(mode == 'percent' ? amount * rate / 100 : rate);
  final tds = r2(payout * tdsPct / 100);
  return CmsResult(payout, tds, r2(payout - tds));
}

// ------------------------------------------------------- shop services
class ShopResult {
  final double payout, tds, charge, net, walletDelta, cashDelta;
  const ShopResult({
    required this.payout,
    required this.tds,
    required this.charge,
    required this.net,
    required this.walletDelta,
    required this.cashDelta,
  });
}

/// Shop service ka hisaab.
/// direction 'cashout' → customer ko cash diya (AEPS, UPI cashout)
/// direction 'cashin'  → customer se cash liya (UPI transfer, recharge)
ShopResult shopCalc({
  required String direction,
  required double payoutPerTxn,
  required double tdsPct,
  required double chargePct,
  required double roundTo,
  required double commPct,
  required double amount,
  required int count,
}) {
  final n = count < 1 ? 1 : count;

  // Company se milne wala payout -- dono direction mein ho sakta hai.
  // DMT/Transfer mein bhi company payout deti hai, aur uspar TDS bhi katta hai.
  final payout = r2(payoutPerTxn * n);
  final tds = r2(payout * tdsPct / 100);

  // Customer se apna extra -- ya to % commission ya round-off charge.
  // Dono set hon to dono jud jaate hain.
  final commission = commPct > 0 ? r2(amount * commPct / 100) : 0.0;
  final roundOff = chargePct > 0
      ? customerCharge(amount, chargePct, roundTo)
      : 0.0;
  final charge = r2(commission + roundOff);

  final isOut = direction == 'cashout';
  return ShopResult(
    payout: payout,
    tds: tds,
    charge: charge,
    net: r2(payout - tds + charge),
    // cashout  = customer ko cash diya  → counter cash −, wallet +
    // cashin   = customer se cash liya  → counter cash +, wallet −
    walletDelta: isOut ? amount : -amount,
    cashDelta: isOut ? -amount : amount,
  );
}

// -------------------------------------------------------- manual payout
/// Raat ko doosre portal ka hisaab. Baad mein edit ho sakta hai.
double manualNet({
  required double payout,
  required double tds,
  required double extra,
}) =>
    r2(payout - tds + extra);

// ------------------------------------------------------------ day totals
class DayProfit {
  final double cmsNet, shopNet, manualNet, distProfit, depositCharges;
  const DayProfit({
    this.cmsNet = 0,
    this.shopNet = 0,
    this.manualNet = 0,
    this.distProfit = 0,
    this.depositCharges = 0,
  });

  double get gross => r2(cmsNet + shopNet + manualNet + distProfit);

  /// Bank charges kaat kar asli profit.
  double get net => r2(gross - depositCharges);
}

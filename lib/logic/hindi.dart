/// Hindi number-to-words + welcome lines — Digitronic Services
///
/// Indian system: hazaar → lakh → crore (western million/billion nahi).
/// ₹1,15,308 → "एक लाख पंद्रह हज़ार तीन सौ आठ रुपये"
library;

// 0-99 tak har number ka apna Hindi naam hai (English jaisa pattern nahi).
const List<String> _ones = [
  '', 'एक', 'दो', 'तीन', 'चार', 'पाँच', 'छह', 'सात', 'आठ', 'नौ',
  'दस', 'ग्यारह', 'बारह', 'तेरह', 'चौदह', 'पंद्रह', 'सोलह', 'सत्रह', 'अठारह', 'उन्नीस',
  'बीस', 'इक्कीस', 'बाईस', 'तेईस', 'चौबीस', 'पच्चीस', 'छब्बीस', 'सत्ताईस', 'अट्ठाईस', 'उनतीस',
  'तीस', 'इकतीस', 'बत्तीस', 'तैंतीस', 'चौंतीस', 'पैंतीस', 'छत्तीस', 'सैंतीस', 'अड़तीस', 'उनतालीस',
  'चालीस', 'इकतालीस', 'बयालीस', 'तैंतालीस', 'चौंतालीस', 'पैंतालीस', 'छियालीस', 'सैंतालीस',
  'अड़तालीस', 'उनचास',
  'पचास', 'इक्यावन', 'बावन', 'तिरेपन', 'चौवन', 'पचपन', 'छप्पन', 'सत्तावन', 'अट्ठावन', 'उनसठ',
  'साठ', 'इकसठ', 'बासठ', 'तिरसठ', 'चौंसठ', 'पैंसठ', 'छियासठ', 'सड़सठ', 'अड़सठ', 'उनहत्तर',
  'सत्तर', 'इकहत्तर', 'बहत्तर', 'तिहत्तर', 'चौहत्तर', 'पचहत्तर', 'छिहत्तर', 'सतहत्तर',
  'अठहत्तर', 'उन्यासी',
  'अस्सी', 'इक्यासी', 'बयासी', 'तिरासी', 'चौरासी', 'पचासी', 'छियासी', 'सत्तासी', 'अट्ठासी',
  'नवासी',
  'नब्बे', 'इक्यानवे', 'बानवे', 'तिरानवे', 'चौरानवे', 'पंचानवे', 'छियानवे', 'सत्तानवे',
  'अट्ठानवे', 'निन्यानवे',
];

/// 0-99 ko Hindi shabdon mein
String _two(int n) => _ones[n];

/// 0-999 ko Hindi shabdon mein
String _three(int n) {
  if (n == 0) return '';
  final h = n ~/ 100, r = n % 100;
  final parts = <String>[];
  if (h > 0) parts.add('${_ones[h]} सौ');
  if (r > 0) parts.add(_two(r));
  return parts.join(' ');
}

/// Poore number ko Hindi shabdon mein (Indian system).
/// 1,15,308 → "एक लाख पंद्रह हज़ार तीन सौ आठ"
String hindiNumber(int n) {
  if (n == 0) return 'शून्य';
  if (n < 0) return 'ऋण ${hindiNumber(-n)}';

  final parts = <String>[];
  // Indian grouping: crore(1e7) → lakh(1e5) → thousand(1e3) → 0-999
  final crore = n ~/ 10000000;
  final lakh = (n % 10000000) ~/ 100000;
  final thousand = (n % 100000) ~/ 1000;
  final rest = n % 1000;

  if (crore > 0) {
    // Crore khud 999 se bada ho sakta hai (jaise 100 crore) — recursion
    parts.add('${crore > 999 ? hindiNumber(crore) : _three(crore)} करोड़');
  }
  if (lakh > 0) parts.add('${_three(lakh)} लाख');
  if (thousand > 0) parts.add('${_three(thousand)} हज़ार');
  if (rest > 0) parts.add(_three(rest));

  return parts.join(' ');
}

/// Rupaye + paise Hindi mein.
/// 1,15,308.50 → "एक लाख पंद्रह हज़ार तीन सौ आठ रुपये पचास पैसे"
String hindiRupees(num? value, {bool paise = true}) {
  final v = (value ?? 0).toDouble();
  final neg = v < 0;
  final abs = v.abs();
  // Paise nikalne se pehle round — 0.1+0.2 wali floating point dikkat se bachne ko
  final total = (abs * 100).round();
  final rupees = total ~/ 100;
  final ps = total % 100;

  final buf = StringBuffer();
  if (neg) buf.write('ऋण ');
  buf.write(hindiNumber(rupees));
  buf.write(' रुपये');
  if (paise && ps > 0) {
    buf.write(' ${hindiNumber(ps)} पैसे');
  }
  return buf.toString();
}

/// Chhota roop — bade amount ke liye "1.15 लाख" jaisa.
/// Dashboard par jagah kam ho to kaam aata hai.
String hindiShort(num? value) {
  final v = (value ?? 0).toDouble().abs();
  final sign = (value ?? 0) < 0 ? '−' : '';
  if (v >= 10000000) return '$sign${(v / 10000000).toStringAsFixed(2)} करोड़';
  if (v >= 100000) return '$sign${(v / 100000).toStringAsFixed(2)} लाख';
  if (v >= 1000) return '$sign${(v / 1000).toStringAsFixed(1)} हज़ार';
  return '$sign${v.toStringAsFixed(0)}';
}

// ------------------------------------------------------------- welcome
/// Samay ke hisaab se greeting
String hindiGreeting([DateTime? at]) {
  final h = (at ?? DateTime.now()).hour;
  if (h < 4) return 'अरे इतनी रात तक जाग रहे हैं बॉस';
  if (h < 12) return 'सुप्रभात बॉस';
  if (h < 17) return 'नमस्ते बॉस';
  if (h < 21) return 'शुभ संध्या बॉस';
  return 'शुभ रात्रि बॉस';
}

/// Mazedaar welcome lines. Har baar alag — bore na ho.
const List<String> welcomeLines = [
  'बॉस आ गए! अब तिजोरी खुलेगी।',
  'लीजिए, आज का हिसाब आपका इंतज़ार कर रहा है।',
  'आ गए हुज़ूर! पैसा गिनने का समय हो गया।',
  'स्वागत है! आज कितना कमाना है?',
  'दुकान खुल गई, अब कमाई शुरू।',
  'हिसाब तैयार है, बस आपकी नज़र चाहिए।',
  'आपके बिना तो कैलकुलेटर भी उदास था।',
  'चलिए बॉस, आज का खाता खोलते हैं।',
  'पैसा आया कि नहीं, अभी पता चल जाएगा।',
  'फिनफ्लोट हाज़िर है, हुक्म कीजिए।',
  'आज भी मुनाफ़ा पक्का, बस एंट्री कर दीजिए।',
  'तिजोरी का ताला खुल गया बॉस।',
];

/// Ek welcome line chunta hai. [seed] dene par wahi line dobara aati hai —
/// isse test likhna aasan ho jaata hai.
String pickWelcome({int? seed, DateTime? at}) {
  final now = at ?? DateTime.now();
  final i = (seed ?? now.millisecondsSinceEpoch) % welcomeLines.length;
  return welcomeLines[i.abs()];
}

/// Poora bola jaane wala vaakya: greeting + line
String welcomeSpeech({int? seed, DateTime? at}) =>
    '${hindiGreeting(at)}। ${pickWelcome(seed: seed, at: at)}';

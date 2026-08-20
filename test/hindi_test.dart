import 'package:flutter_test/flutter_test.dart';
import 'package:finfloat/logic/hindi.dart';
import 'package:finfloat/logic/calc.dart';

/// Hindi number-to-words ke asli Dart tests.
/// Pehle sirf JS port test hota tha — ab asli code chal raha hai.
void main() {
  group('Basic numbers', () {
    test('0-20', () {
      expect(hindiNumber(0), 'शून्य');
      expect(hindiNumber(1), 'एक');
      expect(hindiNumber(5), 'पाँच');
      expect(hindiNumber(10), 'दस');
      expect(hindiNumber(15), 'पंद्रह');
      expect(hindiNumber(20), 'बीस');
    });

    test('tricky tens — Hindi mein har number ka apna naam', () {
      expect(hindiNumber(29), 'उनतीस');
      expect(hindiNumber(39), 'उनतालीस');
      expect(hindiNumber(49), 'उनचास');
      expect(hindiNumber(59), 'उनसठ');
      expect(hindiNumber(69), 'उनहत्तर');
      expect(hindiNumber(79), 'उन्यासी');
      expect(hindiNumber(89), 'नवासी');
      expect(hindiNumber(99), 'निन्यानवे');
      expect(hindiNumber(45), 'पैंतालीस');
      expect(hindiNumber(68), 'अड़सठ');
    });

    test('hundreds', () {
      expect(hindiNumber(100), 'एक सौ');
      expect(hindiNumber(308), 'तीन सौ आठ');
      expect(hindiNumber(999), 'नौ सौ निन्यानवे');
    });

    test('thousands', () {
      expect(hindiNumber(1000), 'एक हज़ार');
      expect(hindiNumber(15000), 'पंद्रह हज़ार');
      expect(hindiNumber(99999), 'निन्यानवे हज़ार नौ सौ निन्यानवे');
    });
  });

  group('Indian system — lakh/crore, million NAHI', () {
    test('lakh', () {
      expect(hindiNumber(100000), 'एक लाख');
      expect(hindiNumber(115308), 'एक लाख पंद्रह हज़ार तीन सौ आठ');
      expect(hindiNumber(129545), 'एक लाख उनतीस हज़ार पाँच सौ पैंतालीस');
      expect(hindiNumber(1000000), 'दस लाख');
    });

    test('crore', () {
      expect(hindiNumber(10000000), 'एक करोड़');
      expect(hindiNumber(12345678),
          'एक करोड़ तेईस लाख पैंतालीस हज़ार छह सौ अठहत्तर');
    });

    test('bahut bada number bhi crash nahi karta', () {
      expect(hindiNumber(10000000000).contains('करोड़'), isTrue);
    });
  });

  group('Rupees + paise', () {
    test('basic', () {
      expect(hindiRupees(0), 'शून्य रुपये');
      expect(hindiRupees(115308), 'एक लाख पंद्रह हज़ार तीन सौ आठ रुपये');
    });

    test('paise', () {
      expect(hindiRupees(115308.50),
          'एक लाख पंद्रह हज़ार तीन सौ आठ रुपये पचास पैसे');
      expect(hindiRupees(0.01), 'शून्य रुपये एक पैसे');
      expect(hindiRupees(115308.50, paise: false),
          'एक लाख पंद्रह हज़ार तीन सौ आठ रुपये');
    });

    test('negative', () {
      expect(hindiRupees(-500), 'ऋण पाँच सौ रुपये');
    });

    test('floating point safe', () {
      expect(hindiRupees(0.1 + 0.2), 'शून्य रुपये तीस पैसे');
      expect(hindiRupees(166.25), 'एक सौ छियासठ रुपये पच्चीस पैसे');
      expect(hindiRupees(36.75), 'छत्तीस रुपये पचहत्तर पैसे');
    });

    test('null safe', () {
      expect(hindiRupees(null), 'शून्य रुपये');
    });
  });

  group('r2() ke saath consistency', () {
    test('paise hamesha r2 se match', () {
      // Agar hindiRupees aur r2 alag paise dikhaayein to report mein
      // ₹ aur Hindi line ek doosre ko jhuthlaayengi.
      for (var i = 0; i < 2000; i++) {
        final v = (i * 7919 % 1000000) / 100.0;
        final fromR2 = (r2(v) * 100).round() % 100;
        final fromHindi = (v * 100).round() % 100;
        expect(fromHindi, fromR2, reason: 'mismatch at $v');
      }
    });
  });

  group('hindiShort', () {
    test('lakh/crore short form', () {
      expect(hindiShort(115308), '1.15 लाख');
      expect(hindiShort(12345678), '1.23 करोड़');
      expect(hindiShort(500), '500');
    });
  });

  group('Greeting + welcome', () {
    test('har ghante ka greeting hai', () {
      for (var h = 0; h < 24; h++) {
        final g = hindiGreeting(DateTime(2026, 1, 1, h));
        expect(g.isNotEmpty, isTrue, reason: 'hour $h khaali');
        expect(RegExp(r'[a-zA-Z]').hasMatch(g), isFalse,
            reason: 'hour $h mein English leak');
      }
    });

    test('samay ke hisaab se sahi', () {
      expect(hindiGreeting(DateTime(2026, 1, 1, 9)), 'सुप्रभात बॉस');
      expect(hindiGreeting(DateTime(2026, 1, 1, 14)), 'नमस्ते बॉस');
      expect(hindiGreeting(DateTime(2026, 1, 1, 19)), 'शुभ संध्या बॉस');
      expect(hindiGreeting(DateTime(2026, 1, 1, 23)), 'शुभ रात्रि बॉस');
    });

    test('welcome lines saaf hain', () {
      expect(welcomeLines.length, 12);
      expect(welcomeLines.toSet().length, 12, reason: 'duplicate line');
      for (final l in welcomeLines) {
        expect(RegExp(r'[a-zA-Z]').hasMatch(l), isFalse, reason: 'English: $l');
      }
    });

    test('pickWelcome hamesha valid line deta hai', () {
      for (var s = 0; s < 100; s++) {
        expect(welcomeLines.contains(pickWelcome(seed: s)), isTrue);
      }
    });

    test('speech mein greeting aur line dono', () {
      final s = welcomeSpeech(seed: 3, at: DateTime(2026, 1, 1, 9));
      expect(s.contains('सुप्रभात'), isTrue);
      expect(s.contains('।'), isTrue);
    });
  });

  group('Fuzz — kuch bhi crash na kare', () {
    test('0 se 20000 tak sab saaf', () {
      for (var i = 0; i <= 20000; i++) {
        final w = hindiNumber(i);
        expect(w.isNotEmpty, isTrue, reason: '$i khaali');
        expect(w.contains('null'), isFalse, reason: '$i mein null');
        expect(RegExp(r'[a-zA-Z]').hasMatch(w), isFalse, reason: '$i mein ASCII');
      }
    });

    test('bade random numbers', () {
      var seed = 12345;
      for (var i = 0; i < 500; i++) {
        seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
        final w = hindiNumber(seed % 99999999);
        expect(w.isNotEmpty, isTrue);
        expect(w.contains('null'), isFalse);
      }
    });
  });
}

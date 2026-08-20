/// Hindi welcome voice — Digitronic Services
///
/// Phone ki apni Text-to-Speech awaaz use karti hai:
///  • 100% offline — koi server, koi API key, koi paid service nahi
///  • APK ka size nahi badhta (koi audio file nahi)
///  • Settings mein ON/OFF switch hai
///
/// Agar phone mein Hindi TTS nahi hai to chup-chaap skip ho jaata hai —
/// app kabhi nahi rukti.
library;

import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/hindi.dart';

class Voice {
  Voice._();
  static final Voice i = Voice._();

  static const _kOn = 'voice_on';
  static const _kLastLine = 'voice_last_line';

  FlutterTts? _tts;
  bool _ready = false;

  /// Aakhri error — Settings screen par dikhane ke liye.
  /// Chhupate nahi hain, par app rokte bhi nahi.
  String? lastError;

  /// Voice ON hai ya nahi (default: ON)
  Future<bool> isOn() async =>
      (await SharedPreferences.getInstance()).getBool(_kOn) ?? true;

  Future<void> setOn(bool v) async {
    (await SharedPreferences.getInstance()).setBool(_kOn, v);
    if (!v) await stop();
  }

  /// TTS engine taiyaar karta hai. Fail ho to false — crash nahi.
  Future<bool> _init() async {
    if (_ready) return true;
    try {
      final t = FlutterTts();
      // Hindi (India). Na mile to engine default par chala jaata hai.
      await t.setLanguage('hi-IN');
      await t.setSpeechRate(0.48); // thoda dheere — saaf sunai de
      await t.setVolume(1.0);
      await t.setPitch(1.05); // halka sa upbeat
      _tts = t;
      _ready = true;
      return true;
    } catch (e) {
      lastError = '$e';
      return false;
    }
  }

  /// Koi bhi Hindi text bolta hai. Voice OFF ho to kuch nahi karta.
  Future<void> say(String text) async {
    if (text.trim().isEmpty) return;
    if (!await isOn()) return;
    if (!await _init()) return;
    try {
      await _tts!.stop();
      await _tts!.speak(text);
    } catch (e) {
      lastError = '$e';
    }
  }

  /// App khulne par swagat. PIN ke turant baad call hota hai.
  ///
  /// Line har baar alag hoti hai — pichhli line yaad rakhkar dobara
  /// nahi bolta, warna maza kam ho jaata.
  Future<void> welcome() async {
    if (!await isOn()) return;
    final p = await SharedPreferences.getInstance();
    final last = p.getInt(_kLastLine) ?? -1;

    var idx = DateTime.now().millisecondsSinceEpoch % welcomeLines.length;
    if (idx == last) idx = (idx + 1) % welcomeLines.length;
    await p.setInt(_kLastLine, idx);

    await say('${hindiGreeting()}। ${welcomeLines[idx]}');
  }

  /// Test/preview ke liye — Settings mein "sunkar dekhein" button
  Future<void> preview() async {
    await say('${hindiGreeting()}। ${welcomeLines.first}');
  }

  /// Kisi amount ko Hindi mein bolna (day-end par kaam aa sakta hai)
  Future<void> sayAmount(num v, {String prefix = ''}) async =>
      say('$prefix ${hindiRupees(v)}');

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // stop fail ho to koi baat nahi
    }
  }
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../data/db.dart';

/// Local PIN. Koi server, koi OTP, koi email.
/// PIN kabhi store nahi hota — sirf salted SHA-256 hash.
///
/// PIN bhool jaane par teen raaste:
///  1. Security question   — aasaan, roz ke liye
///  2. Recovery code       — majboot, setup ke waqt milta hai
///  3. Full reset          — sab mita kar naya shuru (backup se data wapas)
class PinService {
  static const _s = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));

  static const _kHash = 'pin_hash';
  static const _kSalt = 'pin_salt';
  static const _kLen = 'pin_len';
  static const _kQ = 'sec_question';
  static const _kAHash = 'sec_answer_hash';
  static const _kASalt = 'sec_answer_salt';
  static const _kRHash = 'recovery_hash';
  static const _kRSalt = 'recovery_salt';
  static const _kRPlain = 'recovery_plain'; // Settings mein dikhane ke liye

  static int _fails = 0;
  static DateTime? _lockUntil;

  /// Security questions — user inme se ek chunta hai
  static const List<String> questions = [
    'Aapki pehli shop ka naam?',
    'Aapke pita ji ka pehla naam?',
    'Aapka janm sthan (sheher)?',
    'Aapke pehle mobile ka brand?',
    'Aapke bachpan ke dost ka naam?',
    'Aapki favourite jagah?',
  ];

  // ------------------------------------------------------------- helpers
  static String _hash(String value, String salt, String tag) =>
      sha256.convert(utf8.encode('$salt::$value::FinFloatPro::$tag')).toString();

  static String _newSalt() {
    final r = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
  }

  /// Answer normalize — user chhote/bade akshar ya extra space se na atke
  static String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Recovery code: FF-A3K9-M2P7 (aasaan padhne wale characters only)
  static String _genCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // I,O,0,1 hataye
    final r = Random.secure();
    String block() =>
        List.generate(4, (_) => chars[r.nextInt(chars.length)]).join();
    return 'FF-${block()}-${block()}';
  }

  // ---------------------------------------------------------------- state
  static Future<bool> isSet() async => await _s.read(key: _kHash) != null;

  static Future<int> length() async =>
      int.tryParse(await _s.read(key: _kLen) ?? '4') ?? 4;

  static Future<String?> question() async => _s.read(key: _kQ);

  static Future<bool> hasRecovery() async =>
      await _s.read(key: _kRHash) != null;

  /// Recovery code dikhane ke liye (sirf login ke baad Settings se)
  static Future<String?> recoveryCode() async => _s.read(key: _kRPlain);

  static bool get locked =>
      _lockUntil != null && DateTime.now().isBefore(_lockUntil!);

  static int get lockSeconds =>
      locked ? _lockUntil!.difference(DateTime.now()).inSeconds : 0;

  // ------------------------------------------------------------- set PIN
  static Future<void> setPin(String pin) async {
    final salt = _newSalt();
    await _s.write(key: _kSalt, value: salt);
    await _s.write(key: _kHash, value: _hash(pin, salt, 'pin'));
    await _s.write(key: _kLen, value: '${pin.length}');
    _fails = 0;
    _lockUntil = null;
  }

  /// Setup ke waqt security question save karna
  static Future<void> setQuestion(String q, String answer) async {
    final salt = _newSalt();
    await _s.write(key: _kQ, value: q);
    await _s.write(key: _kASalt, value: salt);
    await _s.write(key: _kAHash, value: _hash(_norm(answer), salt, 'ans'));
  }

  /// Naya recovery code banata hai aur wapas deta hai (user ko dikhane ke liye)
  static Future<String> generateRecoveryCode() async {
    final code = _genCode();
    final salt = _newSalt();
    await _s.write(key: _kRSalt, value: salt);
    await _s.write(key: _kRHash, value: _hash(code, salt, 'rec'));
    await _s.write(key: _kRPlain, value: code);
    return code;
  }

  // -------------------------------------------------------------- verify
  static Future<bool> verify(String pin) async {
    if (locked) return false;
    final salt = await _s.read(key: _kSalt);
    final hash = await _s.read(key: _kHash);
    if (salt == null || hash == null) return false;

    final ok = _hash(pin, salt, 'pin') == hash;
    if (ok) {
      _fails = 0;
      _lockUntil = null;
    } else if (++_fails >= 5) {
      _lockUntil = DateTime.now().add(const Duration(seconds: 30));
      _fails = 0;
    }
    return ok;
  }

  static Future<bool> verifyAnswer(String answer) async {
    final salt = await _s.read(key: _kASalt);
    final hash = await _s.read(key: _kAHash);
    if (salt == null || hash == null) return false;
    return _hash(_norm(answer), salt, 'ans') == hash;
  }

  static Future<bool> verifyRecoveryCode(String code) async {
    final salt = await _s.read(key: _kRSalt);
    final hash = await _s.read(key: _kRHash);
    if (salt == null || hash == null) return false;
    // user chhote akshar ya bina dash likhe to bhi chale
    final clean = code.trim().toUpperCase().replaceAll(' ', '');
    final stored = await _s.read(key: _kRPlain);
    if (stored != null && clean == stored.replaceAll(' ', '')) return true;
    return _hash(clean, salt, 'rec') == hash;
  }

  // -------------------------------------------------------------- change
  static Future<bool> change(String oldPin, String newPin) async {
    if (!await verify(oldPin)) return false;
    await setPin(newPin);
    return true;
  }

  /// Reset ke baad naya PIN — purana PIN nahi poochha jaata,
  /// kyunki user pehle hi question/code se identity साबित kar chuka hai.
  static Future<void> resetPin(String newPin) async {
    await setPin(newPin);
    _fails = 0;
    _lockUntil = null;
  }

  /// Lock turant hata do (successful recovery ke baad)
  static void clearLock() {
    _fails = 0;
    _lockUntil = null;
  }

  // ---------------------------------------------------------- full reset
  /// SAB kuch mitata hai — PIN, security question, recovery code, aur database.
  /// Backup se data wapas aa sakta hai. Aakhri raasta.
  static Future<void> factoryReset() async {
    try {
      await DB.i.close();
      final path = await DB.i.path();
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$path$suffix');
        if (await f.exists()) await f.delete();
      }
    } catch (_) {
      // DB pehle se kharab ho to bhi aage badho
    }
    await _s.deleteAll();
    _fails = 0;
    _lockUntil = null;
  }
}

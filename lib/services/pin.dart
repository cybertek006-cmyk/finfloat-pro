import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local PIN only. Koi server, koi OTP, koi email.
/// PIN kabhi store nahi hota — sirf salted SHA-256 hash.
class PinService {
  static const _s = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true));
  static const _kHash = 'pin_hash', _kSalt = 'pin_salt', _kLen = 'pin_len';

  static int _fails = 0;
  static DateTime? _lockUntil;

  static Future<bool> isSet() async => await _s.read(key: _kHash) != null;
  static Future<int> length() async =>
      int.tryParse(await _s.read(key: _kLen) ?? '4') ?? 4;

  static String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt::$pin::FinFloatPro')).toString();

  static Future<void> setPin(String pin) async {
    final r = Random.secure();
    final salt = base64Url.encode(List<int>.generate(16, (_) => r.nextInt(256)));
    await _s.write(key: _kSalt, value: salt);
    await _s.write(key: _kHash, value: _hash(pin, salt));
    await _s.write(key: _kLen, value: '${pin.length}');
    _fails = 0;
    _lockUntil = null;
  }

  static bool get locked =>
      _lockUntil != null && DateTime.now().isBefore(_lockUntil!);
  static int get lockSeconds =>
      locked ? _lockUntil!.difference(DateTime.now()).inSeconds : 0;

  static Future<bool> verify(String pin) async {
    if (locked) return false;
    final salt = await _s.read(key: _kSalt);
    final hash = await _s.read(key: _kHash);
    if (salt == null || hash == null) return false;
    final ok = _hash(pin, salt) == hash;
    if (ok) {
      _fails = 0;
      _lockUntil = null;
    } else if (++_fails >= 5) {
      _lockUntil = DateTime.now().add(const Duration(seconds: 30));
      _fails = 0;
    }
    return ok;
  }

  static Future<bool> change(String oldPin, String newPin) async {
    if (!await verify(oldPin)) return false;
    await setPin(newPin);
    return true;
  }
}

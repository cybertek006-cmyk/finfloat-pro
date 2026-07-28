import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';

/// Backup — dono tareeke, dono FREE:
///
/// 1. ONE-TAP (default, zero setup)
///    App ZIP banata hai → Android ka share sheet khulta hai →
///    aap "Drive" / "Save to Drive" tap karte hain. Bas.
///    Koi Google Cloud account, koi API key nahi chahiye.
///
/// 2. AUTO-SYNC (optional, ~20 min ek baar ka setup)
///    Agar aap Google Cloud Console se free OAuth key bana lein to
///    roz apne aap upload ho sakta hai. Setup guide README mein.
///    Tab tak app one-tap se hi chalega.
class BackupService {
  static const _kLast = 'last_backup_at';
  static const _kReminder = 'backup_reminder';

  /// Sab kuch (database + attachments) ek ZIP mein.
  static Future<File> createZip() async {
    final dbPath = await DB.i.path();
    await DB.i.close(); // WAL flush + lock release

    try {
      final dir = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(dir.path, 'FinFloatPro', 'Backup'));
      if (!await outDir.exists()) await outDir.create(recursive: true);

      final now = DateTime.now();
      final stamp = '${now.year}${_2(now.month)}${_2(now.day)}_'
          '${_2(now.hour)}${_2(now.minute)}';
      final zipPath = p.join(outDir.path, 'FinFloatPro_$stamp.zip');

      final enc = ZipFileEncoder()..create(zipPath);
      for (final suffix in ['', '-wal', '-shm']) {
        final f = File('$dbPath$suffix');
        if (await f.exists()) {
          await enc.addFile(f, 'Database/${p.basename(f.path)}');
        }
      }
      final slips = Directory(p.join(dir.path, 'FinFloatPro', 'Slips'));
      if (await slips.exists()) {
        await enc.addDirectory(slips, includeDirName: true);
      }
      enc.closeSync();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kLast, now.millisecondsSinceEpoch);
      return File(zipPath);
    } finally {
      await DB.i.reopen();
    }
  }

  static String _2(int n) => n.toString().padLeft(2, '0');

  /// ZIP banao aur Android share sheet kholo → "Save to Drive" tap karein.
  static Future<String> backupAndShare() async {
    final f = await createZip();
    final size = (await f.length() / 1024).toStringAsFixed(0);
    await Share.shareXFiles(
      [XFile(f.path)],
      subject: 'FinFloat Pro Backup',
      text: 'FinFloat Pro backup — Google Drive mein save karein',
    );
    return '${p.basename(f.path)} ($size KB)';
  }

  /// Bina share sheet ke, sirf phone mein save.
  static Future<String> backupLocalOnly() async {
    final f = await createZip();
    return f.path;
  }

  /// ZIP file se restore.
  static Future<bool> restoreFromFile() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    final path = res?.files.single.path;
    if (path == null) return false;

    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final dbPath = await DB.i.path();
    final dir = await getApplicationDocumentsDirectory();

    await DB.i.close();
    try {
      for (final e in archive) {
        if (!e.isFile) continue;
        final name = e.name;
        final target = name.startsWith('Database/')
            ? File(p.join(p.dirname(dbPath), p.basename(name)))
            : File(p.join(dir.path, 'FinFloatPro', name));
        await target.parent.create(recursive: true);
        await target.writeAsBytes(e.content as List<int>, flush: true);
      }
      return true;
    } finally {
      await DB.i.reopen();
    }
  }

  static Future<DateTime?> lastBackup() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_kLast);
    return v == null ? null : DateTime.fromMillisecondsSinceEpoch(v);
  }

  static Future<bool> reminderOn() async =>
      (await SharedPreferences.getInstance()).getBool(_kReminder) ?? true;

  static Future<void> setReminder(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_kReminder, v);

  /// Aaj backup hua ya nahi
  static Future<bool> backedUpToday() async {
    final last = await lastBackup();
    if (last == null) return false;
    final now = DateTime.now();
    return last.year == now.year && last.month == now.month && last.day == now.day;
  }

  /// Purane backup 10 se zyada ho to delete
  static Future<void> prune({int keep = 10}) async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(dir.path, 'FinFloatPro', 'Backup'));
    if (!await d.exists()) return;
    final files = (await d.list().toList()).whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (var i = keep; i < files.length; i++) {
      await files[i].delete();
    }
  }

  static Future<List<File>> localBackups() async {
    final dir = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(dir.path, 'FinFloatPro', 'Backup'));
    if (!await d.exists()) return [];
    return (await d.list().toList()).whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
  }
}

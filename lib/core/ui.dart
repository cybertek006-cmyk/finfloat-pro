import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Brand + reusable widgets — Digitronic Services
class C {
  C._();
  static const primary = Color(0xFF0D2A5C);
  static const primaryLight = Color(0xFF1B4B9B);
  static const accent = Color(0xFF17A673);
  static const warning = Color(0xFFF08C00);
  static const error = Color(0xFFD32F2F);
  static const purple = Color(0xFF6B4FBB);
  static const teal = Color(0xFF0E8F8F);
  static const pink = Color(0xFFC2497E);
  static const surface = Color(0xFFF5F7FB);
  static const muted = Color(0xFF6B7A99);
  static const divider = Color(0xFFE3E8F0);
  static const text = Color(0xFF14213D);


  /// Colour ko transparent banata hai.
  /// Seedha withOpacity/withValues use nahi karte kyunki Flutter ke alag
  /// version mein inke naam badal jaate hain. Ye har version par chalta hai.
  static Color fade(Color c, double opacity) {
    return Color.fromRGBO(
      (c.red), (c.green), (c.blue), opacity.clamp(0.0, 1.0));
  }

  static Color hex(String? h) {
    if (h == null || h.isEmpty) return primary;
    return Color(int.parse('FF$h', radix: 16));
  }
}

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _inr0 = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
String money(num? v) => _inr.format(v ?? 0);
String sm(num? v) => _inr0.format(v ?? 0);
String dmy(String iso) {
  try {
    return DateFormat('dd MMM').format(DateTime.parse(iso));
  } catch (_) {
    return iso;
  }
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: C.primary, primary: C.primary, secondary: C.accent),
    scaffoldBackgroundColor: C.surface,
  );
  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: C.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      titleTextStyle:
          TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: C.divider)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: C.divider)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: const BorderSide(color: C.primary, width: 1.6)),
      labelStyle: const TextStyle(color: C.muted, fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.primary,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: C.primary,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: C.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
    // NOTE: cardTheme yahan set nahi karte kyunki Flutter ke naye version mein
    // CardTheme ka naam CardThemeData ho gaya hai. Har version par chale isliye
    // styling apne AppCard widget mein rakhi hai (neeche dekhein).
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
  );
}

// ---------------------------------------------------------------- widgets

/// Card wrapper. Theme mein cardTheme set nahi kiya kyunki Flutter ke alag
/// version mein uska naam badal jaata hai (CardTheme vs CardThemeData).
/// Ye widget har version par same dikhta hai.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final Widget? leftEdge;
  const AppCard({super.key, required this.child, this.padding, this.color, this.leftEdge});

  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x140D2A5C), blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      );
}

void toast(BuildContext c, String msg, {Color? bg}) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: bg ?? C.accent,
      duration: const Duration(seconds: 2),
    ));
}

Future<bool> confirm(BuildContext c, String title, String msg,
    {String ok = 'Delete'}) async {
  return await showDialog<bool>(
        context: c,
        builder: (x) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(onPressed: () => Navigator.pop(x, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: C.error),
              onPressed: () => Navigator.pop(x, true),
              child: Text(ok),
            ),
          ],
        ),
      ) ??
      false;
}


/// FutureBuilder fail ho to ye dikhao -- spinner hamesha ghumne se accha hai.
class ErrBox extends StatelessWidget {
  final Object error;
  const ErrBox(this.error, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('⚠️', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          const Text('Data load nahi hua',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: const Color(0xFFFDF0F0),
                border: Border.all(color: const Color(0xFFF0C0C0)),
                borderRadius: BorderRadius.circular(8)),
            child: SelectableText('$error',
                style: const TextStyle(fontSize: 10.5, height: 1.45)),
          ),
        ]),
      );
}

class Sec extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const Sec(this.title, {super.key, this.trailing});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 8),
        child: Row(children: [
          Text(title,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (trailing != null) trailing!,
        ]),
      );
}

class Row2 extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold, small;
  const Row2(this.label, this.value,
      {super.key, this.color, this.bold = false, this.small = false});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: small ? 11 : 12.5,
                    color: small ? C.muted : C.text,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400)),
          ),
          Text(value,
              style: TextStyle(
                  fontSize: small ? 11 : 12.5,
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: color)),
        ]),
      );
}

class StatCard extends StatelessWidget {
  final String label, value;
  final String icon;
  final Color color;
  const StatCard(this.icon, this.color, this.value, this.label, {super.key});
  @override
  Widget build(BuildContext c) => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                  color: C.fade(color, .12),
                  borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: C.muted)),
          ]),
        ),
      );
}

class Tile extends StatelessWidget {
  final String icon, title, sub;
  final Color color;
  final String? amount, amountSub;
  final Color? amountColor;
  final VoidCallback? onTap, onMenu;
  final Color? edge;
  const Tile({
    super.key,
    required this.icon,
    required this.title,
    required this.sub,
    this.color = C.primary,
    this.amount,
    this.amountSub,
    this.amountColor,
    this.onTap,
    this.onMenu,
    this.edge,
  });

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: edge != null ? Border(left: BorderSide(color: edge!, width: 4)) : null,
          boxShadow: const [
            BoxShadow(color: Color(0x140D2A5C), blurRadius: 3, offset: Offset(0, 1))
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 6, 10),
              child: Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: C.fade(color, .12),
                      borderRadius: BorderRadius.circular(9)),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 15)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        if (sub.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(sub,
                                style: const TextStyle(
                                    fontSize: 10.3, color: C.muted, height: 1.35)),
                          ),
                      ]),
                ),
                if (amount != null)
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(amount!,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: amountColor ?? C.text)),
                    if (amountSub != null)
                      Text(amountSub!,
                          style: const TextStyle(fontSize: 9.3, color: C.muted)),
                  ]),
                if (onMenu != null)
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 18, color: C.muted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    onPressed: onMenu,
                  ),
              ]),
            ),
          ),
        ),
      );
}

class Empty extends StatelessWidget {
  final String icon, title, sub;
  const Empty(this.icon, this.title, {super.key, this.sub = ''});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(children: [
          Text(icon, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
          if (sub.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: C.muted, height: 1.5)),
            ),
        ]),
      );
}

class Note extends StatelessWidget {
  final String text;
  final Color bg, border;
  const Note(this.text,
      {super.key, this.bg = const Color(0xFFF0F4FB), this.border = const Color(0xFFC5D4EE)});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(9)),
        child: Text(text, style: const TextStyle(fontSize: 11.3, height: 1.5)),
      );
}

class Badge2 extends StatelessWidget {
  final String text;
  final Color color;
  const Badge2(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: C.fade(color, .13), borderRadius: BorderRadius.circular(4)),
        child: Text(text,
            style: TextStyle(fontSize: 8.7, fontWeight: FontWeight.w700, color: color)),
      );
}

/// Form text field
class F extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint, suffix;
  final TextInputType? type;
  final int lines;
  final void Function(String)? onChanged;
  const F(this.ctrl, this.label,
      {super.key, this.hint, this.suffix, this.type, this.lines = 1, this.onChanged});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: lines,
          onChanged: onChanged,
          decoration: InputDecoration(labelText: label, hintText: hint, suffixText: suffix),
        ),
      );
}


/// Database se aayi value ko safe double banata hai.
/// SQLite se null ya int/double kuch bhi aa sakta hai, isliye ye wrapper.
double numOf(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}

/// List of DB rows mein se ek column ka total.
double sumOf(List<Map<String, Object?>> rows, String key) {
  var t = 0.0;
  for (final r in rows) {
    t += numOf(r[key]);
  }
  return t;
}

double parseD(TextEditingController c) =>
    double.tryParse(c.text.trim().replaceAll(',', '')) ?? 0;
int parseI(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;

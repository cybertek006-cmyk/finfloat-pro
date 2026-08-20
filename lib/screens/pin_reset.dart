import 'package:flutter/material.dart';
import '../core/ui.dart';
import '../services/pin.dart';

/// PIN bhool gaye — teen raaste
class ForgotPinScreen extends StatefulWidget {
  /// Reset safal hone par call hota hai (naya PIN ban chuka hoga)
  final VoidCallback onReset;
  const ForgotPinScreen({super.key, required this.onReset});

  @override
  State<ForgotPinScreen> createState() => _ForgotPinScreenState();
}

class _ForgotPinScreenState extends State<ForgotPinScreen> {
  String? _question;
  bool _hasRecovery = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _question = await PinService.question();
    _hasRecovery = await PinService.hasRecovery();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PIN Bhool Gaye?')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Note(
                'Apni pehchaan saabit karein, phir naya PIN bana sakte hain. '
                'Aapka data surakshit rahega.',
              ),
              const SizedBox(height: 4),

              // --------- Option 1: Security question ---------
              if (_question != null)
                _option(
                  icon: '❓',
                  color: C.accent,
                  title: 'Security Question',
                  sub: _question!,
                  onTap: () => _openStep(_VerifyStep.question, _question!),
                )
              else
                _disabled('❓', 'Security Question',
                    'Aapne setup ke waqt question nahi banaya tha'),

              // --------- Option 2: Recovery code ---------
              if (_hasRecovery)
                _option(
                  icon: '🔑',
                  color: C.primary,
                  title: 'Recovery Code',
                  sub: 'Wo code jo setup ke waqt mila tha (FF-XXXX-XXXX)',
                  onTap: () => _openStep(_VerifyStep.code, ''),
                )
              else
                _disabled('🔑', 'Recovery Code',
                    'Aapne recovery code save nahi kiya tha'),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              // --------- Option 3: Factory reset ---------
              const Text('Aakhri Raasta',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF0F0),
                  border: Border.all(color: const Color(0xFFF0C0C0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(children: [
                  const Text(
                    '⚠️ Sab kuch mit jaayega — companies, entries, reports, sab. '
                    'Agar aapke paas backup file hai to reset ke baad usse '
                    'poora data wapas aa jaayega.',
                    style: TextStyle(fontSize: 11.5, height: 1.5),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.error),
                    onPressed: _factoryReset,
                    child: const Text('🗑️ Sab Mitakar Naya Shuru Karein'),
                  ),
                ]),
              ),
            ]),
    );
  }

  Widget _option({
    required String icon,
    required Color color,
    required String title,
    required String sub,
    required VoidCallback onTap,
  }) =>
      Tile(icon: icon, color: color, title: title, sub: sub, onTap: onTap);

  Widget _disabled(String icon, String title, String sub) => Opacity(
        opacity: .45,
        child: Tile(icon: icon, color: C.muted, title: title, sub: sub),
      );

  Future<void> _openStep(_VerifyStep step, String question) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => _VerifyScreen(step: step, question: question),
      ),
    );
    if (ok == true && mounted) {
      Navigator.pop(context);
      widget.onReset();
    }
  }

  Future<void> _factoryReset() async {
    final ok = await confirm(
      context,
      'Sab kuch mitayein?',
      'Poora data delete ho jaayega. Ye wapas nahi aayega '
          '(backup file se chhod kar). Pakka?',
      ok: 'Haan, Mitayein',
    );
    if (!ok) return;

    // Do baar poochte hain — ye bahut bada kadam hai
    if (!mounted) return;
    final sure = await confirm(
      context,
      'Aakhri baar pooch rahe hain',
      'Iske baad aapko app naye sire se setup karni padegi.',
      ok: 'Delete',
    );
    if (!sure) return;

    await PinService.factoryReset();
    if (!mounted) return;
    Navigator.pop(context);
    widget.onReset();
    toast(context, 'Sab reset ho gaya — naya PIN banayein', bg: C.warning);
  }
}

enum _VerifyStep { question, code }

/// Answer/code check karke naya PIN banwata hai
class _VerifyScreen extends StatefulWidget {
  final _VerifyStep step;
  final String question;
  const _VerifyScreen({required this.step, required this.question});

  @override
  State<_VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends State<_VerifyScreen> {
  final _input = TextEditingController();
  final _pin1 = TextEditingController();
  final _pin2 = TextEditingController();

  bool _verified = false;
  bool _busy = false;
  String? _err;
  int _tries = 0;

  bool get _isQ => widget.step == _VerifyStep.question;

  @override
  void dispose() {
    _input.dispose();
    _pin1.dispose();
    _pin2.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final v = _input.text.trim();
    if (v.isEmpty) {
      setState(() => _err = _isQ ? 'Jawab likhein' : 'Code likhein');
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
    });

    final ok = _isQ
        ? await PinService.verifyAnswer(v)
        : await PinService.verifyRecoveryCode(v);

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (ok) {
        _verified = true;
      } else {
        _tries++;
        _err = _isQ
            ? 'Jawab galat hai (koshish $_tries)'
            : 'Code galat hai (koshish $_tries)';
      }
    });
  }

  Future<void> _save() async {
    final a = _pin1.text.trim(), b = _pin2.text.trim();
    if (a.length != 4 && a.length != 6) {
      setState(() => _err = 'PIN 4 ya 6 digit ka hona chahiye');
      return;
    }
    if (a != b) {
      setState(() => _err = 'Dono PIN match nahi kar rahe');
      return;
    }
    setState(() => _busy = true);
    await PinService.resetPin(a);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_isQ ? 'Security Question' : 'Recovery Code')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (!_verified) ...[
          if (_isQ)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F4FB),
                border: Border.all(color: const Color(0xFFC5D4EE)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(widget.question,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            )
          else
            const Note(
              'Setup ke waqt jo code mila tha wo daalein.\n'
              'Format: FF-XXXX-XXXX (chhote akshar bhi chalenge)',
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _input,
            autofocus: true,
            textCapitalization:
                _isQ ? TextCapitalization.none : TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: _isQ ? 'Aapka jawab' : 'Recovery code',
              hintText: _isQ ? '' : 'FF-A3K9-M2P7',
            ),
            onSubmitted: (_) => _check(),
          ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!,
                  style: const TextStyle(
                      color: C.error, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _check,
            child: Text(_busy ? 'Check ho raha hai…' : 'Aage Badhein'),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F4),
              border: Border.all(color: const Color(0xFFBFE3D3)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('✅ Pehchaan ho gayi — ab naya PIN banayein',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
          _pinField(_pin1, 'Naya PIN (4 ya 6 digit)'),
          _pinField(_pin2, 'Naya PIN dobara'),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(_err!,
                  style: const TextStyle(
                      color: C.error, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Save ho raha hai…' : 'Naya PIN Save Karein'),
          ),
          const SizedBox(height: 10),
          const Note('Naya PIN kahin likh kar rakhein.'),
        ],
      ]),
    );
  }

  Widget _pinField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(labelText: label, counterText: ''),
        ),
      );
}

/// Setup ke waqt: security question + recovery code banwana
class RecoverySetupScreen extends StatefulWidget {
  /// true = setup ke turant baad (skip allowed)
  final bool firstTime;
  const RecoverySetupScreen({super.key, this.firstTime = false});

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  String _q = PinService.questions.first;
  final _ans = TextEditingController();
  String? _code;
  bool _busy = false;

  @override
  void dispose() {
    _ans.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_ans.text.trim().length < 2) {
      toast(context, 'Jawab likhein', bg: C.error);
      return;
    }
    setState(() => _busy = true);
    await PinService.setQuestion(_q, _ans.text);
    final code = await PinService.generateRecoveryCode();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _code = code;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PIN Recovery Setup'),
        automaticallyImplyLeading: !widget.firstTime,
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_code == null) ...[
          const Note(
            'PIN bhool jaayein to inhi se wapas milega. '
            'Ye phone mein hi save hoga, kahin bheja nahi jaata.',
          ),
          const SizedBox(height: 6),
          const Text('Security Question chunein',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...PinService.questions.map((q) => RadioListTile<String>(
                value: q,
                groupValue: _q,
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(q, style: const TextStyle(fontSize: 13)),
                onChanged: (v) => setState(() => _q = v!),
              )),
          const SizedBox(height: 10),
          TextField(
            controller: _ans,
            decoration: const InputDecoration(labelText: 'Aapka jawab *'),
          ),
          const SizedBox(height: 8),
          const Note(
            'Chhote-bade akshar se farak nahi padta. '
            'Aisa jawab chunein jo aap kabhi na bhoolein.',
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Save ho raha hai…' : 'Save Karein'),
          ),
          if (widget.firstTime) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Abhi nahi — baad mein karunga'),
            ),
          ],
        ] else ...[
          // Recovery code dikhao
          const Text('🔑 Aapka Recovery Code',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: C.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: SelectableText(
                _code!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC),
              border: Border.all(color: const Color(0xFFF5D9A8)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              '📝 Ye code kahin likh kar rakhein — diary mein, ya kisi '
              'surakshit jagah.\n\n'
              'PIN bhool jaayein to isse naya PIN bana sakte hain.\n\n'
              'Baad mein bhi dekh sakte hain: More → Change PIN → Recovery Code',
              style: TextStyle(fontSize: 11.5, height: 1.6),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: C.accent),
            onPressed: () => Navigator.pop(context),
            child: const Text('✅ Likh liya — Aage Badhein'),
          ),
        ],
      ]),
    );
  }
}

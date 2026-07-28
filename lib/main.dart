import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/ui.dart';
import 'data/db.dart';
import 'data/repo.dart';
import 'screens/dashboard.dart';
import 'screens/day_dialog.dart';
import 'screens/more.dart';
import 'screens/reports.dart';
import 'screens/tabs.dart';
import 'services/pin.dart';

/// FinFloat Pro — Digitronic Services
/// Offline Fintech Float Management System
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: C.primary, statusBarIconBrightness: Brightness.light));

  // Database khol kar default services daalte hain.
  // Fail ho to error YAAD rakhte hain aur screen par dikhate hain --
  // chhupate nahi, warna app hamesha loading dikhati rahegi.
  String? bootError;
  try {
    await DB.i.db;
    await DB.i.seedServices();
  } catch (e, st) {
    bootError = '$e\n\n$st';
  }

  runApp(App(bootError: bootError));
}

class App extends StatefulWidget {
  final String? bootError;
  const App({super.key, this.bootError});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  bool _authed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // App background mein jaaye to lock
    if (s == AppLifecycleState.paused && _authed) {
      setState(() => _authed = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'FinFloat Pro',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: widget.bootError != null
            ? BootErrorScreen(message: widget.bootError!)
            : (_authed
                ? Home(onLogout: () => setState(() => _authed = false))
                : PinScreen(onOk: () => setState(() => _authed = true))),
      );
}

/// ------------------------------------------------------------ PIN SCREEN
class PinScreen extends StatefulWidget {
  final VoidCallback onOk;
  const PinScreen({super.key, required this.onOk});
  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '', _first = '';
  int _len = 4;
  String? _err;
  bool _setup = false, _ready = false, _busy = false;

  @override
  void initState() {
    super.initState();
    PinService.isSet().then((set) async {
      _len = set ? await PinService.length() : 4;
      if (mounted) setState(() {
        _setup = !set;
        _ready = true;
      });
    });
  }

  Future<void> _tap(String k) async {
    if (_busy) return;
    if (k == '<') {
      if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
      return;
    }
    if (_pin.length >= _len) return;
    setState(() {
      _pin += k;
      _err = null;
    });
    if (_pin.length == _len) await _submit();
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    HapticFeedback.selectionClick();
    try {
      if (_setup) {
        if (_first.isEmpty) {
          setState(() {
            _first = _pin;
            _pin = '';
          });
        } else if (_first == _pin) {
          await PinService.setPin(_pin);
          widget.onOk();
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _err = 'PIN match nahi kiya. Dobara try karein.';
            _first = '';
            _pin = '';
          });
        }
      } else {
        if (PinService.locked) {
          setState(() {
            _err = '${PinService.lockSeconds}s baad try karein';
            _pin = '';
          });
        } else if (await PinService.verify(_pin)) {
          widget.onOk();
        } else {
          HapticFeedback.heavyImpact();
          setState(() {
            _err = 'Galat PIN';
            _pin = '';
          });
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
          backgroundColor: C.primary,
          body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    final title = _setup
        ? (_first.isEmpty ? 'Naya PIN banayein' : 'PIN dobara daalein')
        : 'Apna PIN daalein';

    return Scaffold(
      backgroundColor: C.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 20),
              Container(
                width: 66,
                height: 66,
                decoration: BoxDecoration(
                    color: Colors.white, borderRadius: BorderRadius.circular(18)),
                alignment: Alignment.center,
                child: const Text('💼', style: TextStyle(fontSize: 32)),
              ),
              const SizedBox(height: 14),
              const Text('FinFloat Pro',
                  style: TextStyle(
                      color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
              const Text('Offline Fintech Float Management',
                  style: TextStyle(color: Colors.white70, fontSize: 11.5)),
              const SizedBox(height: 26),
              Text(title,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _len,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _pin.length
                            ? C.accent
                            : C.fade(Colors.white, .22)),
                  ),
                ),
              ),
              SizedBox(
                height: 34,
                child: Center(
                  child: _err != null
                      ? Text(_err!,
                          style: const TextStyle(
                              color: Color(0xFFFFB4AB),
                              fontSize: 12,
                              fontWeight: FontWeight.w600))
                      : (_setup && _first.isEmpty
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [4, 6]
                                  .map((n) => GestureDetector(
                                        onTap: () => setState(() {
                                          _len = n;
                                          _pin = '';
                                        }),
                                        child: Container(
                                          margin:
                                              const EdgeInsets.symmetric(horizontal: 5),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 13, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: _len == n
                                                ? Colors.white
                                                : C.fade(Colors.white, .13),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text('$n digit',
                                              style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: _len == n
                                                      ? C.primary
                                                      : Colors.white)),
                                        ),
                                      ))
                                  .toList(),
                            )
                          : const SizedBox()),
                ),
              ),
              SizedBox(
                width: 240,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.5,
                  children: [
                    ...['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<']
                        .map((k) => k.isEmpty
                            ? const SizedBox()
                            : InkResponse(
                                onTap: () => _tap(k),
                                radius: 36,
                                child: Center(
                                  child: k == '<'
                                      ? const Icon(Icons.backspace_outlined,
                                          color: Colors.white, size: 21)
                                      : Text(k,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 24)),
                                ),
                              )),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Digitronic Services · v1.0',
                  style: TextStyle(color: Colors.white38, fontSize: 10)),
              const SizedBox(height: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

/// ----------------------------------------------------------------- HOME

/// Agar app start hote hi database fail ho jaaye to ye screen dikhti hai.
/// Chhupane se accha hai ki asli wajah saaf dikhe.
class BootErrorScreen extends StatelessWidget {
  final String message;
  const BootErrorScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: C.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                const Text('⚠️', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 12),
                const Text('Database khul nahi paaya',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                const Text(
                  'Ye screenshot bhej dijiye — exact wajah neeche likhi hai.',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        message,
                        style: const TextStyle(
                            color: Color(0xFFFFD7D2),
                            fontSize: 11,
                            height: 1.5,
                            fontFamily: 'monospace'),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class Home extends StatefulWidget {
  final VoidCallback onLogout;
  const Home({super.key, required this.onLogout});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _tab = 0;
  int _version = 0; // badha kar sab tabs refresh hote hain

  static const _titles = [
    'FinFloat Pro',
    'Shop Day Book',
    'CMS Collection',
    'Manual Payout',
    'Counter Cash',
    'Reports',
    'More',
  ];

  @override
  void initState() {
    super.initState();
    // Pehli baar khulne par Day Start popup
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final done = await Repo.i.hasSnap('open');
      final accs = await Repo.i.accounts();
      if (!done && accs.isNotEmpty && mounted) {
        await showDayDialog(context, 'open');
        _bump();
      }
    });
  }

  void _bump() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardTab(key: ValueKey('d$_version'), onChanged: _bump),
      ShopTab(key: ValueKey('s$_version'), onChanged: _bump),
      CmsTab(key: ValueKey('c$_version'), onChanged: _bump),
      PayoutTab(key: ValueKey('p$_version'), onChanged: _bump),
      CashTab(key: ValueKey('h$_version'), onChanged: _bump),
      ReportsTab(key: ValueKey('r$_version')),
      MoreTab(key: ValueKey('m$_version'), onChanged: _bump, onLogout: widget.onLogout),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_titles[_tab]),
            if (_tab == 0)
              Text(
                '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: const TextStyle(fontSize: 10.5, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _bump),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Text('📊', style: TextStyle(fontSize: 17)), label: 'Dash'),
          NavigationDestination(icon: Text('🏪', style: TextStyle(fontSize: 17)), label: 'Shop'),
          NavigationDestination(icon: Text('💵', style: TextStyle(fontSize: 17)), label: 'CMS'),
          NavigationDestination(icon: Text('✋', style: TextStyle(fontSize: 17)), label: 'Payout'),
          NavigationDestination(icon: Text('💰', style: TextStyle(fontSize: 17)), label: 'Cash'),
          NavigationDestination(icon: Text('📄', style: TextStyle(fontSize: 17)), label: 'Report'),
          NavigationDestination(icon: Text('☰', style: TextStyle(fontSize: 17)), label: 'More'),
        ],
      ),
    );
  }
}

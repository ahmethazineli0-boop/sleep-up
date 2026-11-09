import 'package:flutter/material.dart';

import '../services/blocker_channel.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/demo_banner.dart';

class _Perm {
  final String key, title, subtitle;
  final bool required;
  const _Perm(this.key, this.title, this.subtitle, {this.required = true});
}

const _androidPerms = [
  _Perm('accessibility', 'Erişilebilirlik hizmeti',
      'Kilitli bir uygulama açıldığında kilit ekranını göstermek için. Ekrandaki içeriği okumaz, kaydetmez.'),
  _Perm('notifications', 'Bildirimler', 'Rahatlama hatırlatması için', required: false),
];

const _iosPerms = [
  _Perm('screenTime', 'Ekran Süresi erişimi', 'Apple Family Controls ile uygulamaları kısıtlamak için'),
  _Perm('selection', 'Uygulama seçimi', 'Kilitlenecek uygulama ve kategorileri seçmek için'),
  _Perm('notifications', 'Bildirimler', 'Rahatlama hatırlatması için', required: false),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with WidgetsBindingObserver {
  Map<String, bool> _granted = {};
  bool _intro = true;

  List<_Perm> get _perms => BlockerChannel.isIOS ? _iosPerms : _androidPerms;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final g = await BlockerChannel.permissions();
    if (mounted) setState(() => _granted = g);
  }

  bool get _ready =>
      widget.state.demo || _perms.where((p) => p.required).every((p) => _granted[p.key] == true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: _intro ? _introBody() : _permBody(),
        ),
      ),
    );
  }

  Widget _introBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Spacer(),
        Container(
          width: 88,
          height: 88,
          decoration: const BoxDecoration(color: SU.surface, shape: BoxShape.circle),
          child: const Icon(Icons.bedtime, color: SU.amber, size: 42),
        ),
        const SizedBox(height: 28),
        const Text('Telefonun da\nuyusun.', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.15)),
        const SizedBox(height: 14),
        const Text(
          'Sleep Up, belirlediğin saatte dikkatini dağıtan uygulamaları kilitler. '
          'Ekrana değil, uykuna ve sabahına zaman kalır.',
          style: TextStyle(fontSize: 16, color: SU.muted, height: 1.5),
        ),
        const Spacer(flex: 2),
        FilledButton(onPressed: () => setState(() => _intro = false), child: const Text('Başlayalım')),
      ]);

  Widget _permBody() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Gece kilidi için birkaç izin gerekiyor',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2)),
        const SizedBox(height: 10),
        const Text(
          'Sleep Up hiçbir veriyi telefonundan dışarı göndermez. İzinler yalnızca kilit saatinde uygulamaları durdurmak için kullanılır.',
          style: TextStyle(fontSize: 15, color: SU.muted, height: 1.5),
        ),
        const SizedBox(height: 22),
        if (widget.state.demo)
          const DemoBanner()
        else
        for (var i = 0; i < _perms.length; i++) ...[
          _PermCard(
            index: i + 1,
            perm: _perms[i],
            granted: _granted[_perms[i].key] == true,
            onGrant: () async {
              if (_perms[i].key == 'accessibility') {
                final go = await _explainAccessibility();
                if (go != true) return;
              }
              await BlockerChannel.request(_perms[i].key);
              await _check();
            },
          ),
          const SizedBox(height: 12),
        ],
        const Spacer(),
        FilledButton(
          onPressed: _ready ? widget.state.finishOnboarding : null,
          child: const Text('Devam et'),
        ),
      ]);

  /// Google Play, erişilebilirlik API'si kullanımının açıkça anlatılmasını ister.
  Future<bool?> _explainAccessibility() => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: SU.surface,
          title: const Text('Erişilebilirlik izni'),
          content: const Text(
            'Sleep Up, erişilebilirlik hizmetini YALNIZCA hangi uygulamanın ön plana geldiğini '
            'anlamak ve kilit saatinde kilit ekranını göstermek için kullanır. Ekran içeriği, '
            'yazdıkların veya kişisel verilerin okunmaz, saklanmaz, paylaşılmaz.\n\n'
            'Açılan ayarlarda "Sleep Up"ı bulup etkinleştir.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Şimdi değil')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kabul et'),
            ),
          ],
        ),
      );
}

class _PermCard extends StatelessWidget {
  const _PermCard({required this.index, required this.perm, required this.granted, required this.onGrant});
  final int index;
  final _Perm perm;
  final bool granted;
  final VoidCallback onGrant;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: SU.surfaceHi, borderRadius: BorderRadius.circular(12)),
              child: Text('$index', style: const TextStyle(color: SU.amber, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(perm.required ? perm.title : '${perm.title} (isteğe bağlı)',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(perm.subtitle, style: const TextStyle(fontSize: 12, color: SU.muted, height: 1.4)),
              ]),
            ),
            const SizedBox(width: 8),
            granted
                ? const Icon(Icons.check_circle, color: SU.mint, semanticLabel: 'Verildi')
                : FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 14)),
                    onPressed: onGrant,
                    child: const Text('İzin ver', style: TextStyle(fontSize: 13)),
                  ),
          ]),
        ),
      );
}

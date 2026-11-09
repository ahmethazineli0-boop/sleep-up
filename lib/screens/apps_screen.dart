import 'package:flutter/material.dart';

import '../services/blocker_channel.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/demo_banner.dart';

/// Kilitlenecek uygulamalar.
/// Android: yüklü uygulamalar listesi. iOS: Apple'ın uygulama seçicisi
/// (Apple, uygulama listesini üçüncü taraf uygulamalara vermez).
class AppsScreen extends StatefulWidget {
  const AppsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<AppsScreen> createState() => _AppsScreenState();
}

class _AppsScreenState extends State<AppsScreen> {
  List<InstalledApp>? _apps;
  String _query = '';

  @override
  void initState() {
    super.initState();
    if (!BlockerChannel.isIOS) {
      BlockerChannel.installedApps().then((a) {
        if (mounted) setState(() => _apps = a);
      });
    }
  }

  Future<void> _save({String? mode, List<String>? packages}) async {
    final s = widget.state.schedule.copyWith(blockMode: mode, blockedPackages: packages);
    final ok = await widget.state.saveSchedule(s);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sıkı mod: kilit sırasında değiştirilemez')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state.schedule;
        final all = s.blockMode == 'all';
        final locked = widget.state.editingLocked;
        return AbsorbPointer(
          absorbing: locked,
          child: CustomScrollView(slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.list(children: [
                const Text('Neler kilitlensin?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('Hepsi kilitli')),
                    ButtonSegment(value: 'selected', label: Text('Seçtiklerim')),
                  ],
                  selected: {s.blockMode},
                  onSelectionChanged: (v) => _save(mode: v.first),
                ),
                const SizedBox(height: 10),
                Text(
                  all
                      ? (BlockerChannel.isIOS
                          ? 'Her şey kilitlenir; seçtiklerin istisna olur. Acil açma için Sleep Up\'ı da istisnalara ekle.'
                          : 'Her şey kilitlenir; işaretlediklerin istisna olur. Telefon, saat ve Sleep Up her zaman açıktır.')
                      : 'Yalnızca seçtiklerin kilit saatinde kapanır.',
                  style: const TextStyle(fontSize: 13, color: SU.muted, height: 1.45),
                ),
                const SizedBox(height: 18),
                if (BlockerChannel.isIOS) ..._iosBody() else ..._androidHeader(),
              ]),
            ),
            if (!BlockerChannel.isIOS) _androidList(all),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ]),
        );
      },
    );
  }

  List<Widget> _iosBody() {
    final n = widget.state.iosSelectionCount;
    return [
      Card(
        child: ListTile(
          leading: const Icon(Icons.apps, color: SU.amber),
          title: Text(n == 0 ? 'Henüz seçim yok' : '$n uygulama, kategori ya da site'),
          subtitle: const Text('Apple\'ın seçicisiyle düzenlenir', style: TextStyle(color: SU.muted, fontSize: 12)),
        ),
      ),
      const SizedBox(height: 16),
      if (widget.state.demo) ...[const DemoBanner(), const SizedBox(height: 16)],
      FilledButton(
        onPressed: widget.state.demo ? null : () async {
          await BlockerChannel.request('selection');
          await widget.state.saveSchedule(widget.state.schedule);
        },
        child: Text(widget.state.schedule.blockMode == 'all' ? 'İstisnaları seç' : 'Uygulama seç'),
      ),
    ];
  }

  List<Widget> _androidHeader() => [
        TextField(
          decoration: InputDecoration(
            hintText: 'Uygulama ara',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: SU.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _query = v.toLowerCase()),
        ),
        const SizedBox(height: 8),
      ];

  Widget _androidList(bool all) {
    final apps = _apps;
    if (apps == null) {
      return const SliverToBoxAdapter(
          child: Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
    }
    final picked = widget.state.schedule.blockedPackages.toSet();
    final shown = apps.where((a) => a.label.toLowerCase().contains(_query)).toList();
    return SliverList.builder(
      itemCount: shown.length,
      itemBuilder: (c, i) {
        final a = shown[i];
        final on = picked.contains(a.package);
        return CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(a.label),
          subtitle: Text(
            all ? (on ? 'İstisna — açık kalır' : 'Kilitlenir') : (on ? 'Kilitlenir' : 'Açık kalır'),
            style: const TextStyle(fontSize: 12, color: SU.muted),
          ),
          value: on,
          onChanged: (v) {
            final next = {...picked};
            v == true ? next.add(a.package) : next.remove(a.package);
            _save(packages: next.toList());
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../models/sleep_schedule.dart';
import '../services/blocker_channel.dart';
import '../state/app_state.dart';
import '../theme.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.state});
  final AppState state;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _NightRow {
  final DateTime day;
  final bool scheduled;
  final int emergency;
  final int blocked;
  _NightRow(this.day, this.scheduled, this.emergency, this.blocked);
  bool get kept => scheduled && emergency == 0;
}

class _StatsScreenState extends State<StatsScreen> {
  NightStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
    widget.state.addListener(_load);
  }

  @override
  void dispose() {
    widget.state.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final s = await BlockerChannel.stats();
    if (mounted) setState(() => _stats = s);
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<_NightRow> _nights(int count) {
    final sched = widget.state.schedule;
    final stats = _stats ?? const NightStats();
    final now = DateTime.now();
    // En son TAMAMLANMIŞ gece: bugünün gecesi henüz bitmedi.
    final todayKey = SleepSchedule.nightKey(now, sched.endMinutes);
    final parts = todayKey.split('-').map(int.parse).toList();
    final current = DateTime(parts[0], parts[1], parts[2]);
    return List.generate(count, (i) {
      final d = DateTime(current.year, current.month, current.day - count + i);
      final k = _key(d);
      return _NightRow(d, sched.days.contains(d.weekday), stats.emergency[k] ?? 0, stats.blocked[k] ?? 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    final week = _nights(7);
    final history = _nights(60);
    var streak = 0;
    for (final n in history.reversed) {
      if (!n.scheduled) continue;
      if (!n.kept) break;
      streak++;
    }
    final scheduled = week.where((n) => n.scheduled).length;
    final kept = week.where((n) => n.kept).length;
    final blocked = week.fold<int>(0, (a, n) => a + n.blocked);
    final emergency = week.fold<int>(0, (a, n) => a + n.emergency);
    final weekendSlips = week.where((n) => n.emergency > 0 && n.day.weekday >= 5).length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const Text('Son 7 gece', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Kilide uyduğun geceler', style: TextStyle(fontSize: 14, color: SU.muted)),
                Text('$kept/$scheduled', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 16),
              SizedBox(
                height: 150,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final n in week)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor: !n.scheduled ? 0.08 : (n.kept ? 1.0 : 0.4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: !n.scheduled ? SU.line : (n.kept ? SU.amber : SU.dim),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(dayShort[n.day.weekday - 1],
                                style: const TextStyle(fontSize: 11, color: SU.muted)),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Wrap(spacing: 16, runSpacing: 6, children: [
                _Legend(color: SU.amber, text: 'Tam uyum'),
                _Legend(color: SU.dim, text: 'Acil açma kullanıldı'),
                _Legend(color: SU.line, text: 'Program yok'),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _Tile('Şu anki seri', '$streak gece'),
            _Tile('Engellenen açılış', '$blocked'),
            _Tile('Acil açma', '$emergency kez'),
            _Tile('Program', '${fmtHm(widget.state.schedule.startMinutes)}–${fmtHm(widget.state.schedule.endMinutes)}'),
          ],
        ),
        const SizedBox(height: 12),
        if (_insight(scheduled, kept, weekendSlips) case final text?)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1A1E36), borderRadius: BorderRadius.circular(20)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.lightbulb_outline, color: SU.lavender, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.45))),
            ]),
          ),
      ],
    );
  }

  /// Basit, kurala dayalı öneriler (yalnızca cihazdaki veriden).
  String? _insight(int scheduled, int kept, int weekendSlips) {
    if (scheduled == 0) return 'Programında gün seçili değil. Program sekmesinden en az birkaç gece seç.';
    if (weekendSlips >= 2) {
      return 'Acil açmaları çoğunlukla hafta sonu kullanıyorsun. Cuma ve cumartesi için kilidi biraz ileri almayı dene.';
    }
    if (kept == scheduled) return 'Tüm gecelerde kilide uydun. Ritmini korumak için açılış saatini hafta sonu da aynı tut.';
    if (kept * 2 < scheduled) {
      return 'Kilit sık bozuluyor. Kilidi 30 dk geç başlatıp her hafta 10 dk öne çekmek daha kolay olabilir.';
    }
    return null;
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, color: SU.muted)),
      ]);
}

class _Tile extends StatelessWidget {
  const _Tile(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: SU.muted)),
            const SizedBox(height: 6),
            FittedBox(child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600))),
          ]),
        ),
      );
}

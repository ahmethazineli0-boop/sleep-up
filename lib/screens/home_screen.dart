import 'package:flutter/material.dart';

import '../models/sleep_schedule.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/countdown_ring.dart';
import '../widgets/demo_banner.dart';

const _months = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz',
  'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
const _weekdays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state, required this.onNavigate});
  final AppState state;
  final void Function(int tab) onNavigate;

  String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 5) return 'İyi geceler';
    if (h < 12) return 'Günaydın';
    if (h < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final now = DateTime.now();
        final s = state.schedule;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Text('${_weekdays[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                style: const TextStyle(fontSize: 13, color: SU.muted)),
            const SizedBox(height: 2),
            Text(_greeting(now), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            if (state.demo) ...[const DemoBanner(), const SizedBox(height: 16)],
            _HeroCard(state: state, now: now),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: _StatTile(
                  label: 'Program',
                  value: '${fmtHm(s.startMinutes)}–${fmtHm(s.endMinutes)}',
                  footer: '${s.days.length} gün',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Engellenen',
                  value: s.blockMode == 'all' ? 'Tümü' : '${state.blockedCount} öğe',
                  footer: 'Düzenle',
                  onTap: () => onNavigate(2),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            if (!state.lockActive) ...[
              FilledButton(
                onPressed: () async {
                  final ok = await _confirmStartNow(context, s);
                  if (ok == true) {
                    final started = await state.startNow();
                    if (!started && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(state.demo
                              ? 'Deneme sürümünde kilit kapalı.'
                              : 'Kilit başlatılamadı. İzinleri kontrol et.')));
                    }
                  }
                },
                child: const Text('Şimdi uyku moduna geç'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => onNavigate(1), child: const Text('Programı düzenle')),
            ] else
              _EmergencyButton(state: state),
          ],
        );
      },
    );
  }

  Future<bool?> _confirmStartNow(BuildContext context, SleepSchedule s) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          backgroundColor: SU.surface,
          title: const Text('Şimdi uyuyor musun?'),
          content: Text('Seçili uygulamalar ${fmtHm(s.endMinutes)}\'e kadar kilitlenecek.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Kilitle'),
            ),
          ],
        ),
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.state, required this.now});
  final AppState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = state.schedule;
    final emergencyUntil = state.native.emergencyUntil;
    late final CountdownRing ring;
    String? chip;

    if (emergencyUntil != null && emergencyUntil.isAfter(now)) {
      final left = emergencyUntil.difference(now);
      ring = CountdownRing(
        progress: left.inSeconds / 300,
        caption: 'Acil açma',
        value: fmtDuration(left + const Duration(minutes: 1)),
        footer: 'Sonra kilit geri döner',
        color: SU.lavender,
      );
    } else if (state.lockActive) {
      final until = state.native.lockUntil ?? s.activeWindow(now)?.$2 ?? s.nextWake(now);
      final left = until.difference(now);
      final total = s.durationMinutes.toDouble();
      ring = CountdownRing(
        progress: 1 - left.inMinutes / total,
        caption: 'Telefon uyuyor',
        value: fmtDuration(left),
        footer: 'Açılış ${fmtHm(until.hour * 60 + until.minute)}',
        color: SU.lavender,
      );
      chip = 'Uyumak için en iyi an şimdi';
    } else {
      final next = s.nextStart(now);
      if (next == null) {
        ring = const CountdownRing(
            progress: 0, caption: 'Program', value: 'Kapalı', footer: 'Gün seçilmedi');
      } else {
        final left = next.difference(now);
        final awake = (24 * 60 - s.durationMinutes).toDouble();
        ring = CountdownRing(
          progress: 1 - left.inMinutes / awake,
          caption: 'Kilide kalan',
          value: fmtDuration(left),
          footer: 'Kilit ${fmtHm(s.startMinutes)} · Açılış ${fmtHm(s.endMinutes)}',
        );
        if (s.windDownEnabled) {
          final wd = next.subtract(Duration(minutes: s.windDownMinutes));
          chip = now.isBefore(wd)
              ? 'Rahatlama modu ${fmtHm(wd.hour * 60 + wd.minute)}\'da başlar'
              : 'Rahatlama zamanı: ekranı bırakmaya başla';
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        child: Column(children: [
          ring,
          if (chip != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: SU.surfaceHi, borderRadius: BorderRadius.circular(999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.bedtime_outlined, size: 16, color: SU.lavender),
                const SizedBox(width: 8),
                Flexible(child: Text(chip, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.footer, this.onTap});
  final String label, value, footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12, color: SU.muted)),
            const SizedBox(height: 6),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(footer,
                style: TextStyle(fontSize: 12, color: onTap != null ? SU.amber : SU.muted)),
          ]),
        ),
      ),
    );
  }
}

/// Acil açma: kullanıcıdan bir cümle yazmasını ister (dürtüsel açmayı yavaşlatır).
class _EmergencyButton extends StatelessWidget {
  const _EmergencyButton({required this.state});
  final AppState state;
  static const phrase = 'uyumam gerekiyor ama bu acil';

  @override
  Widget build(BuildContext context) {
    final emergencyUntil = state.native.emergencyUntil;
    if (emergencyUntil != null && emergencyUntil.isAfter(DateTime.now())) {
      return const SizedBox.shrink();
    }
    final available = state.emergencyAvailable;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Zihnin hâlâ meşgulse: aklındakini bir kâğıda yaz, telefonu yatağın dışına bırak.',
            style: TextStyle(fontSize: 14, height: 1.45, color: SU.text),
          ),
        ),
      ),
      const SizedBox(height: 10),
      OutlinedButton(
        onPressed: available ? () => _ask(context) : null,
        child: Text(available ? 'Acil açma (5 dk)' : 'Bu gecelik acil açma hakkın bitti'),
      ),
    ]);
  }

  Future<void> _ask(BuildContext context) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setLocal) => AlertDialog(
          backgroundColor: SU.surface,
          title: const Text('Emin misin?'),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Devam etmek için şunu yaz:'),
            const SizedBox(height: 6),
            const Text(phrase, style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: ctrl, autofocus: true, onChanged: (_) => setLocal(() {})),
          ]),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(88, 44)),
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Vazgeç, uyu'),
            ),
            TextButton(
              onPressed: ctrl.text.trim().toLowerCase() == phrase ? () => Navigator.pop(c, true) : null,
              child: const Text('5 dk aç'),
            ),
          ],
        ),
      ),
    );
    // Diyalog kapanış animasyonu bitince bırak.
    Future.delayed(const Duration(milliseconds: 400), ctrl.dispose);
    if (ok == true) {
      final done = await state.emergencyUnlock();
      if (!done && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Acil açma kullanılamadı.')));
      }
    }
  }
}

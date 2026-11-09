import 'package:flutter/material.dart';

import '../models/sleep_schedule.dart';
import '../state/app_state.dart';
import '../theme.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late SleepSchedule draft = widget.state.schedule;

  /// Uygulama seçimi başka ekranda değişebilir; onu her zaman güncel durumdan al.
  SleepSchedule get _merged => draft.copyWith(
        blockMode: widget.state.schedule.blockMode,
        blockedPackages: widget.state.schedule.blockedPackages,
      );

  bool get dirty =>
      _merged.toJson().toString() != widget.state.schedule.toJson().toString();

  Future<void> _pickTime(bool start) async {
    final cur = start ? draft.startMinutes : draft.endMinutes;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    final m = t.hour * 60 + t.minute;
    setState(() => draft = start ? draft.copyWith(startMinutes: m) : draft.copyWith(endMinutes: m));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final locked = widget.state.editingLocked;
        final hours = draft.durationMinutes / 60;
        return AbsorbPointer(
          absorbing: locked,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              const Text('Uyku programı', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              if (locked) ...[
                const SizedBox(height: 12),
                const _Banner('Sıkı mod açık: kilit bitene kadar program değiştirilemez.'),
              ],
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: _TimeCard(label: 'Kilit', icon: Icons.lock_outline, iconColor: SU.amber,
                    value: fmtHm(draft.startMinutes), highlighted: true, onTap: () => _pickTime(true))),
                const SizedBox(width: 12),
                Expanded(child: _TimeCard(label: 'Açılış', icon: Icons.wb_sunny_outlined, iconColor: SU.lavender,
                    value: fmtHm(draft.endMinutes), onTap: () => _pickTime(false))),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text('${hours.toStringAsFixed(hours % 1 == 0 ? 0 : 1)} saat uyku penceresi'
                    '${hours < 7 ? ' · yetişkinler için 7–9 saat önerilir' : ''}',
                    style: const TextStyle(fontSize: 13, color: SU.muted)),
              ),
              const SizedBox(height: 24),
              const Text('Hangi günler', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(
                children: List.generate(7, (i) {
                  final day = i + 1;
                  final on = draft.days.contains(day);
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 6 ? 6 : 0),
                      child: Semantics(
                        button: true,
                        selected: on,
                        child: Material(
                          color: on ? SU.amber : Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(color: on ? SU.amber : SU.line),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => setState(() {
                              final d = {...draft.days};
                              on ? d.remove(day) : d.add(day);
                              draft = draft.copyWith(days: d);
                            }),
                            child: SizedBox(
                              height: 44,
                              child: Center(
                                child: Text(dayShort[i],
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: on ? SU.onAmber : SU.muted)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(children: [
                  SwitchListTile(
                    title: const Text('Rahatlama modu'),
                    subtitle: Text('Kilitten ${draft.windDownMinutes} dk önce hatırlatma',
                        style: const TextStyle(color: SU.muted, fontSize: 12)),
                    value: draft.windDownEnabled,
                    onChanged: (v) => setState(() => draft = draft.copyWith(windDownEnabled: v)),
                  ),
                  if (draft.windDownEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 15, label: Text('15 dk')),
                          ButtonSegment(value: 30, label: Text('30 dk')),
                          ButtonSegment(value: 60, label: Text('60 dk')),
                        ],
                        selected: {draft.windDownMinutes},
                        onSelectionChanged: (v) =>
                            setState(() => draft = draft.copyWith(windDownMinutes: v.first)),
                      ),
                    ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Acil açma hakkı'),
                    subtitle: const Text('Gecede kaç kez, 5 dakikalığına',
                        style: TextStyle(color: SU.muted, fontSize: 12)),
                    trailing: DropdownButton<int>(
                      value: draft.emergencyPerNight,
                      underline: const SizedBox.shrink(),
                      dropdownColor: SU.surfaceHi,
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Yok')),
                        DropdownMenuItem(value: 1, child: Text('1')),
                        DropdownMenuItem(value: 2, child: Text('2')),
                      ],
                      onChanged: (v) => setState(() => draft = draft.copyWith(emergencyPerNight: v)),
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Sıkı mod'),
                    subtitle: const Text('Kilit saatinde ayarlar değiştirilemez',
                        style: TextStyle(color: SU.muted, fontSize: 12)),
                    value: draft.strictMode,
                    onChanged: (v) => setState(() => draft = draft.copyWith(strictMode: v)),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: dirty
                    ? () async {
                        final ok = await widget.state.saveSchedule(_merged);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ok ? 'Program kaydedildi' : 'Kilit sırasında değiştirilemez')));
                      }
                    : null,
                child: const Text('Kaydet'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.onTap,
    this.highlighted = false,
  });
  final String label, value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SU.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: highlighted ? SU.amber : SU.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, color: SU.muted)),
            ]),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SU.surfaceHi, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.lock, size: 18, color: SU.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ]),
      );
}

/// Kullanıcının gece kilidi ayarları.
///
/// Saatler gece yarısından itibaren dakika olarak tutulur (23:00 = 1380).
/// Günler [DateTime.weekday] ile aynı: 1 = Pazartesi ... 7 = Pazar.
/// Bir gece, BAŞLADIĞI güne aittir: Cuma 23:00 → Cumartesi 07:00 "Cuma gecesi"dir.
class SleepSchedule {
  final int startMinutes;
  final int endMinutes;
  final Set<int> days;
  final bool windDownEnabled;
  final int windDownMinutes;
  final bool strictMode;
  final int emergencyPerNight;

  /// 'selected' → yalnızca seçilen uygulamalar; 'all' → izinli liste dışındaki her şey.
  final String blockMode;

  /// Android paket adları. iOS'ta seçim, Apple'ın şifreli token'ları olarak
  /// native tarafta saklanır; burada kullanılmaz.
  final List<String> blockedPackages;

  const SleepSchedule({
    this.startMinutes = 23 * 60,
    this.endMinutes = 7 * 60,
    this.days = const {1, 2, 3, 4, 5, 6, 7},
    this.windDownEnabled = true,
    this.windDownMinutes = 30,
    this.strictMode = false,
    this.emergencyPerNight = 1,
    this.blockMode = 'selected',
    this.blockedPackages = const [],
  });

  SleepSchedule copyWith({
    int? startMinutes,
    int? endMinutes,
    Set<int>? days,
    bool? windDownEnabled,
    int? windDownMinutes,
    bool? strictMode,
    int? emergencyPerNight,
    String? blockMode,
    List<String>? blockedPackages,
  }) =>
      SleepSchedule(
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        days: days ?? this.days,
        windDownEnabled: windDownEnabled ?? this.windDownEnabled,
        windDownMinutes: windDownMinutes ?? this.windDownMinutes,
        strictMode: strictMode ?? this.strictMode,
        emergencyPerNight: emergencyPerNight ?? this.emergencyPerNight,
        blockMode: blockMode ?? this.blockMode,
        blockedPackages: blockedPackages ?? this.blockedPackages,
      );

  Map<String, dynamic> toJson() => {
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'days': (days.toList()..sort()),
        'windDownEnabled': windDownEnabled,
        'windDownMinutes': windDownMinutes,
        'strictMode': strictMode,
        'emergencyPerNight': emergencyPerNight,
        'blockMode': blockMode,
        'blockedPackages': blockedPackages,
      };

  factory SleepSchedule.fromJson(Map<String, dynamic> j) => SleepSchedule(
        startMinutes: j['startMinutes'] as int? ?? 23 * 60,
        endMinutes: j['endMinutes'] as int? ?? 7 * 60,
        days: ((j['days'] as List?) ?? const [1, 2, 3, 4, 5, 6, 7]).cast<int>().toSet(),
        windDownEnabled: j['windDownEnabled'] as bool? ?? true,
        windDownMinutes: j['windDownMinutes'] as int? ?? 30,
        strictMode: j['strictMode'] as bool? ?? false,
        emergencyPerNight: j['emergencyPerNight'] as int? ?? 1,
        blockMode: j['blockMode'] as String? ?? 'selected',
        blockedPackages: ((j['blockedPackages'] as List?) ?? const []).cast<String>(),
      );

  /// Uyku penceresinin uzunluğu (dakika). Gece yarısını geçebilir.
  int get durationMinutes {
    final d = endMinutes - startMinutes;
    return d > 0 ? d : d + 24 * 60;
  }

  DateTime _at(DateTime day, int minutes) =>
      DateTime(day.year, day.month, day.day).add(Duration(minutes: minutes));

  /// [night] gününde başlayan gecenin başlangıç ve bitişi.
  (DateTime, DateTime) windowFor(DateTime night) {
    final start = _at(night, startMinutes);
    final end = start.add(Duration(minutes: durationMinutes));
    return (start, end);
  }

  /// Şu an aktif olan pencere (yoksa null).
  (DateTime, DateTime)? activeWindow(DateTime now) {
    for (final offset in const [0, -1]) {
      final night = DateTime(now.year, now.month, now.day + offset);
      if (!days.contains(night.weekday)) continue;
      final (s, e) = windowFor(night);
      if (!now.isBefore(s) && now.isBefore(e)) return (s, e);
    }
    return null;
  }

  /// Bir sonraki kilidin başlangıcı (en fazla 8 gün ileri bakar).
  DateTime? nextStart(DateTime now) {
    for (var i = 0; i < 8; i++) {
      final night = DateTime(now.year, now.month, now.day + i);
      if (!days.contains(night.weekday)) continue;
      final (s, _) = windowFor(night);
      if (s.isAfter(now)) return s;
    }
    return null;
  }

  /// "Şimdi uyu" için: bir sonraki uyanma saati.
  DateTime nextWake(DateTime now) {
    var wake = _at(now, endMinutes);
    if (!wake.isAfter(now)) wake = wake.add(const Duration(days: 1));
    return wake;
  }

  /// Bir anın ait olduğu gecenin tarih anahtarı (yyyy-MM-dd).
  /// Native taraf da aynı kuralı uygular: bitiş saatinden önceki sabah saatleri
  /// bir önceki geceye sayılır.
  static String nightKey(DateTime t, int endMinutes) {
    final m = t.hour * 60 + t.minute;
    final d = m < endMinutes ? DateTime(t.year, t.month, t.day - 1) : t;
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

String fmtHm(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '$m dk';
  if (m == 0) return '$h sa';
  return '$h sa $m dk';
}

const dayShort = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

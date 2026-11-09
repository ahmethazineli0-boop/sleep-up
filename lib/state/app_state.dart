import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sleep_schedule.dart';
import '../services/blocker_channel.dart';

/// Uygulamanın tek durum nesnesi. Ekranlar [ListenableBuilder] ile dinler.
class AppState extends ChangeNotifier {
  static const _kSchedule = 'schedule_v1';
  static const _kOnboarded = 'onboarded_v1';

  late SharedPreferences _prefs;
  SleepSchedule schedule = const SleepSchedule();
  bool onboarded = false;
  bool loaded = false;
  NativeStatus native = const NativeStatus();
  int iosSelectionCount = 0;
  Timer? _ticker;

  /// Deneme sürümü: native kilit katmanı yok (ör. ücretsiz hesapla yüklenen iOS).
  bool demo = false;

  DateTime get now => DateTime.now();

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    demo = !await BlockerChannel.checkAvailable();
    final raw = _prefs.getString(_kSchedule);
    if (raw != null) {
      schedule = SleepSchedule.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    onboarded = _prefs.getBool(_kOnboarded) ?? false;
    loaded = true;
    await refresh();
    // Native taraf uygulama güncellemesi vb. sonrası boş kalmasın.
    if (onboarded) await BlockerChannel.applySchedule(schedule);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  Future<void> refresh() async {
    native = await BlockerChannel.status();
    if (BlockerChannel.isIOS) {
      iosSelectionCount = await BlockerChannel.iosSelectionCount();
    }
    notifyListeners();
  }

  /// Kilit şu an açık mı (program, "şimdi uyu" ya da acil açma dahil).
  bool get lockActive {
    if (demo) return false;
    final emergency = native.emergencyUntil;
    if (emergency != null && emergency.isAfter(now)) return false;
    return native.lockActive || schedule.activeWindow(now) != null;
  }

  /// Sıkı modda kilit sırasında ayarlar değiştirilemez.
  bool get editingLocked => schedule.strictMode && lockActive;

  int get blockedCount =>
      BlockerChannel.isIOS ? iosSelectionCount : schedule.blockedPackages.length;

  Future<bool> saveSchedule(SleepSchedule s) async {
    if (editingLocked) return false;
    schedule = s;
    await _prefs.setString(_kSchedule, jsonEncode(s.toJson()));
    await BlockerChannel.applySchedule(s);
    await refresh();
    return true;
  }

  Future<void> finishOnboarding() async {
    onboarded = true;
    await _prefs.setBool(_kOnboarded, true);
    await BlockerChannel.applySchedule(schedule);
    notifyListeners();
  }

  Future<bool> startNow() async {
    final ok = await BlockerChannel.startNow(schedule.nextWake(now));
    await refresh();
    return ok;
  }

  bool get emergencyAvailable =>
      native.emergencyUsedTonight < schedule.emergencyPerNight;

  Future<bool> emergencyUnlock() async {
    if (!emergencyAvailable) return false;
    final ok = await BlockerChannel.emergencyUnlock(5);
    await refresh();
    return ok;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}

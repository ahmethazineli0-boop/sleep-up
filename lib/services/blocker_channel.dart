import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../models/sleep_schedule.dart';

/// Native kilitleme katmanı ile köprü.
///
/// Android: Kotlin (AccessibilityService + UsageStats).
/// iOS: Swift (FamilyControls + ManagedSettings + DeviceActivity).
/// Kanal adı ve metot isimleri iki platformda aynıdır.
class BlockerChannel {
  static const _ch = MethodChannel('sleepup/blocker');

  static bool get isIOS => Platform.isIOS;

  /// Native kilit katmanı bu derlemede var mı?
  /// iOS deneme sürümünde (ücretsiz Apple hesabı) yoktur: arayüz çalışır, kilit çalışmaz.
  static bool nativeAvailable = true;

  static Future<bool> checkAvailable() async {
    try {
      await _ch.invokeMethod('getStatus');
      nativeAvailable = true;
    } on MissingPluginException {
      nativeAvailable = false;
    }
    return nativeAvailable;
  }

  /// Android: {usage, accessibility, notifications}
  /// iOS:     {screenTime, selection, notifications}
  static Future<Map<String, bool>> permissions() async {
    final r = await _invoke<Map>('getPermissions');
    return (r ?? const {}).map((k, v) => MapEntry(k as String, v == true));
  }

  /// İzin ekranını açar ya da sistem iznini ister. iOS'ta 'selection'
  /// Apple'ın uygulama seçicisini (FamilyActivityPicker) gösterir.
  static Future<bool> request(String permission) async =>
      await _invoke<bool>('requestPermission', {'permission': permission}) ?? false;

  /// Yalnızca Android: başlatıcıda görünen uygulamalar.
  static Future<List<InstalledApp>> installedApps() async {
    final r = await _invoke<List>('getInstalledApps') ?? const [];
    return r
        .map((e) => InstalledApp(e['package'] as String, e['label'] as String))
        .toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  }

  /// Yalnızca iOS: kaç uygulama/kategori/site seçili.
  static Future<int> iosSelectionCount() async =>
      await _invoke<int>('getSelectionCount') ?? 0;

  /// Programı native tarafa yazar ve zamanlamaları yeniden kurar.
  static Future<void> applySchedule(SleepSchedule s) =>
      _invoke('applySchedule', s.toJson());

  /// Kilidi hemen başlatır, [until] anına kadar sürer.
  static Future<bool> startNow(DateTime until) async =>
      await _invoke<bool>('startNow', {'untilMillis': until.millisecondsSinceEpoch}) ?? false;

  /// Acil açma. Gece hakkı bittiyse false döner.
  static Future<bool> emergencyUnlock(int minutes) async =>
      await _invoke<bool>('emergencyUnlock', {'minutes': minutes}) ?? false;

  static Future<NativeStatus> status() async {
    final r = await _invoke<Map>('getStatus') ?? const {};
    return NativeStatus(
      lockActive: r['lockActive'] == true,
      lockUntil: _date(r['lockUntilMillis']),
      emergencyUntil: _date(r['emergencyUntilMillis']),
      emergencyUsedTonight: (r['emergencyUsedTonight'] as int?) ?? 0,
    );
  }

  /// Gece anahtarı (yyyy-MM-dd) → sayı.
  static Future<NightStats> stats() async {
    final r = await _invoke<Map>('getStats') ?? const {};
    Map<String, int> m(Object? x) =>
        ((x as Map?) ?? const {}).map((k, v) => MapEntry(k as String, (v as num).toInt()));
    return NightStats(blocked: m(r['blocked']), emergency: m(r['emergency']));
  }

  static DateTime? _date(Object? ms) =>
      ms is int && ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null;

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on MissingPluginException {
      // Masaüstü/web önizlemesi: native katman yok.
      return null;
    }
  }
}

class InstalledApp {
  final String package;
  final String label;
  const InstalledApp(this.package, this.label);
}

class NativeStatus {
  final bool lockActive;
  final DateTime? lockUntil;
  final DateTime? emergencyUntil;
  final int emergencyUsedTonight;
  const NativeStatus({
    this.lockActive = false,
    this.lockUntil,
    this.emergencyUntil,
    this.emergencyUsedTonight = 0,
  });
}

class NightStats {
  final Map<String, int> blocked;
  final Map<String, int> emergency;
  const NightStats({this.blocked = const {}, this.emergency = const {}});
}

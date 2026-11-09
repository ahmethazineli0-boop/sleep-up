// Flutter ↔ iOS köprüsü: kanal 'sleepup/blocker'.
// Apple Screen Time API: FamilyControls (izin + seçici),
// ManagedSettings (kalkan), DeviceActivity (zamanlama).

import DeviceActivity
import FamilyControls
import Flutter
import ManagedSettings
import SwiftUI
import UIKit
import UserNotifications

final class BlockerPlugin: NSObject, FlutterPlugin {

    private let store = SharedStore.shared
    private let center = DeviceActivityCenter()

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "sleepup/blocker", binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(BlockerPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        switch call.method {
        case "getPermissions":
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                let notif = settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                DispatchQueue.main.async {
                    result([
                        "screenTime": AuthorizationCenter.shared.authorizationStatus == .approved,
                        "selection": self.store.selectionCount > 0,
                        "notifications": notif,
                    ])
                }
            }

        case "requestPermission":
            request(args["permission"] as? String ?? "", result: result)

        case "getInstalledApps":
            result([]) // iOS uygulama listesini vermez; seçici kullanılır.

        case "getSelectionCount":
            result(store.selectionCount)

        case "applySchedule":
            do {
                let data = try JSONSerialization.data(withJSONObject: args)
                let cfg = try JSONDecoder().decode(ScheduleConfig.self, from: data)
                store.schedule = cfg
                applySchedule(cfg)
                result(nil)
            } catch {
                result(FlutterError(code: "bad_schedule", message: error.localizedDescription, details: nil))
            }

        case "startNow":
            let ms = (args["untilMillis"] as? NSNumber)?.doubleValue ?? 0
            result(startNow(until: Date(timeIntervalSince1970: ms / 1000)))

        case "emergencyUnlock":
            result(emergencyUnlock(minutes: args["minutes"] as? Int ?? 5))

        case "getStatus":
            let now = Date()
            result([
                "lockActive": store.isLockActive(now),
                "lockUntilMillis": millis(store.lockUntil(now)),
                "emergencyUntilMillis": millis(store.emergencyUntil),
                "emergencyUsedTonight": store.emergencyUsedTonight(now),
            ])

        case "getStats":
            result(["blocked": store.stat("stats_blocked"), "emergency": store.stat("stats_emergency")])

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func millis(_ d: Date?) -> Int {
        guard let d else { return 0 }
        return Int(d.timeIntervalSince1970 * 1000)
    }

    // MARK: İzinler

    private func request(_ permission: String, result: @escaping FlutterResult) {
        switch permission {
        case "screenTime":
            Task { @MainActor in
                do {
                    try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
                    result(true)
                } catch {
                    result(false)
                }
            }
        case "selection":
            presentPicker(result: result)
        case "notifications":
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { ok, _ in
                DispatchQueue.main.async { result(ok) }
            }
        default:
            result(false)
        }
    }

    private func presentPicker(result: @escaping FlutterResult) {
        guard let top = Self.topViewController() else { result(false); return }
        var host: UIHostingController<PickerSheet>!
        let sheet = PickerSheet(initial: store.selection) { [weak self] picked in
            if let picked { self?.store.selection = picked }
            host.dismiss(animated: true) {
                // Seçim değiştiyse ve kilit açıksa kalkanı hemen güncelle.
                if let self, self.store.isLockActive() { self.store.applyShield() }
                result(picked != nil)
            }
        }
        host = UIHostingController(rootView: sheet)
        top.present(host, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    // MARK: Zamanlama

    /// ISO gün (1=Pzt..7=Paz) → Apple gün (1=Paz..7=Cmt)
    private func appleWeekday(_ iso: Int) -> Int { iso % 7 + 1 }

    private func applySchedule(_ cfg: ScheduleConfig) {
        let nights = center.activities.filter { $0.isNight }
        center.stopMonitoring(nights)

        let start = (h: cfg.startMinutes / 60, m: cfg.startMinutes % 60)
        let end = (h: cfg.endMinutes / 60, m: cfg.endMinutes % 60)
        do {
            if Set(cfg.days).count == 7 {
                // Her gece: tek, günlük tekrarlayan program (gece yarısını geçebilir).
                try center.startMonitoring(.nightDaily, during: DeviceActivitySchedule(
                    intervalStart: DateComponents(hour: start.h, minute: start.m),
                    intervalEnd: DateComponents(hour: end.h, minute: end.m),
                    repeats: true))
            } else {
                for d in cfg.days {
                    let endDay = cfg.crossesMidnight ? d % 7 + 1 : d
                    try center.startMonitoring(.night(d), during: DeviceActivitySchedule(
                        intervalStart: DateComponents(hour: start.h, minute: start.m, weekday: appleWeekday(d)),
                        intervalEnd: DateComponents(hour: end.h, minute: end.m, weekday: appleWeekday(endDay)),
                        repeats: true))
                }
            }
        } catch {
            NSLog("SleepUp: izleme başlatılamadı: \(error)")
        }

        // Şu an pencerenin içindeysek beklemeden uygula; değilsek temizle.
        if store.isLockActive() { store.applyShield() } else if !store.isEmergencyActive() { store.clearShield() }
        scheduleWindDown(cfg)
    }

    private func oneShot(from: Date, to: Date, warning: DateComponents? = nil) -> DeviceActivitySchedule {
        let cal = Calendar.current
        let comps: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        return DeviceActivitySchedule(
            intervalStart: cal.dateComponents(comps, from: from),
            intervalEnd: cal.dateComponents(comps, from: to),
            repeats: false,
            warningTime: warning)
    }

    private func startNow(until: Date) -> Bool {
        guard AuthorizationCenter.shared.authorizationStatus == .approved, store.schedule != nil else { return false }
        let now = Date()
        guard until > now else { return false }
        store.manualUntil = until
        store.emergencyUntil = nil
        store.applyShield()
        // DeviceActivity en az 15 dk'lık aralık ister; bitişte Monitor kalkanı kaldırır.
        let end = max(until, now.addingTimeInterval(15 * 60))
        center.stopMonitoring([.manual])
        try? center.startMonitoring(.manual, during: oneShot(from: now, to: end))
        return true
    }

    /// Acil açma: kalkanı kaldırır; 15 dk'lık tek seferlik aralığın
    /// "bitmeden 10 dk önce" uyarısı (= 5. dakika) Monitor'da kalkanı geri koyar.
    private func emergencyUnlock(minutes: Int) -> Bool {
        let now = Date()
        guard let cfg = store.schedule, store.isLockActive(now),
              store.emergencyUsedTonight(now) < cfg.emergencyPerNight else { return false }
        let m = max(1, min(minutes, 14))
        store.emergencyUntil = now.addingTimeInterval(TimeInterval(m * 60))
        store.bump("stats_emergency", now)
        store.clearShield()
        center.stopMonitoring([.emergency])
        do {
            try center.startMonitoring(.emergency, during: oneShot(
                from: now, to: now.addingTimeInterval(15 * 60),
                warning: DateComponents(minute: 15 - m)))
        } catch {
            // Zamanlanamazsa açık bırakma.
            store.emergencyUntil = nil
            store.applyShield()
            return false
        }
        return true
    }

    // MARK: Rahatlama bildirimi

    private func scheduleWindDown(_ cfg: ScheduleConfig) {
        let nc = UNUserNotificationCenter.current()
        nc.removePendingNotificationRequests(withIdentifiers: (1...7).map { "winddown_\($0)" })
        guard cfg.windDownEnabled else { return }

        var at = cfg.startMinutes - cfg.windDownMinutes
        var dayShift = 0
        if at < 0 { at += 24 * 60; dayShift = -1 } // hatırlatma önceki güne düşer

        let content = UNMutableNotificationContent()
        content.title = "Rahatlama zamanı"
        content.body = "\(cfg.windDownMinutes) dakika sonra uygulamaların kilitlenecek. Ekranı bırakmaya başla."
        content.sound = .default

        for d in cfg.days {
            let iso = ((d - 1 + dayShift) % 7 + 7) % 7 + 1
            var comps = DateComponents()
            comps.weekday = appleWeekday(iso)
            comps.hour = at / 60
            comps.minute = at % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            nc.add(UNNotificationRequest(identifier: "winddown_\(d)", content: content, trigger: trigger))
        }
    }
}

/// Apple'ın uygulama/kategori seçicisi.
struct PickerSheet: View {
    @State private var selection: FamilyActivitySelection
    let onDone: (FamilyActivitySelection?) -> Void

    init(initial: FamilyActivitySelection, onDone: @escaping (FamilyActivitySelection?) -> Void) {
        _selection = State(initialValue: initial)
        self.onDone = onDone
    }

    var body: some View {
        NavigationView {
            FamilyActivityPicker(selection: $selection)
                .navigationTitle("Uygulama seç")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Vazgeç") { onDone(nil) }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Kaydet") { onDone(selection) }
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}

// Ortak durum: Runner uygulaması VE üç uzantı (Monitor, Shield, ShieldAction)
// tarafından kullanılır. Xcode'da bu dosyanın "Target Membership" kısmında
// dört hedefin de işaretli olması gerekir.

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum SUConfig {
    /// Xcode > Signing & Capabilities > App Groups'ta oluşturduğun grup ile AYNI olmalı.
    static let appGroup = "group.com.sleepup.sleepup"
}

struct ScheduleConfig: Codable {
    var startMinutes: Int
    var endMinutes: Int
    /// 1 = Pazartesi ... 7 = Pazar
    var days: [Int]
    var windDownEnabled: Bool
    var windDownMinutes: Int
    var strictMode: Bool
    var emergencyPerNight: Int
    /// "selected" → seçilenler kilitlenir; "all" → her şey kilitlenir, seçilenler istisna.
    var blockMode: String

    var durationMinutes: Int {
        let d = endMinutes - startMinutes
        return d > 0 ? d : d + 24 * 60
    }

    var crossesMidnight: Bool { endMinutes <= startMinutes }
}

extension DeviceActivityName {
    static let nightDaily = Self("night_daily")
    static func night(_ isoWeekday: Int) -> Self { Self("night_\(isoWeekday)") }
    static let manual = Self("manual")
    static let emergency = Self("emergency")

    var isNight: Bool { rawValue.hasPrefix("night_") }
}

final class SharedStore {
    static let shared = SharedStore()

    private let defaults: UserDefaults
    private let managed = ManagedSettingsStore()
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .current
        return c
    }

    private init() {
        defaults = UserDefaults(suiteName: SUConfig.appGroup) ?? .standard
    }

    // MARK: Program ve seçim

    var schedule: ScheduleConfig? {
        get {
            guard let d = defaults.data(forKey: "schedule") else { return nil }
            return try? JSONDecoder().decode(ScheduleConfig.self, from: d)
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "schedule") }
    }

    var selection: FamilyActivitySelection {
        get {
            guard let d = defaults.data(forKey: "selection"),
                  let s = try? JSONDecoder().decode(FamilyActivitySelection.self, from: d)
            else { return FamilyActivitySelection() }
            return s
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: "selection") }
    }

    var selectionCount: Int {
        let s = selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    var manualUntil: Date? {
        get { defaults.object(forKey: "manualUntil") as? Date }
        set { defaults.set(newValue, forKey: "manualUntil") }
    }

    var emergencyUntil: Date? {
        get { defaults.object(forKey: "emergencyUntil") as? Date }
        set { defaults.set(newValue, forKey: "emergencyUntil") }
    }

    // MARK: Zaman hesapları (Dart ve Kotlin ile aynı kurallar)

    private func startOfNight(dayOffset: Int, from now: Date, _ s: ScheduleConfig) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now))!
        return calendar.date(byAdding: .minute, value: s.startMinutes, to: day)!
    }

    /// Calendar.weekday (Pazar=1) → 1 = Pazartesi ... 7 = Pazar
    func isoWeekday(_ date: Date) -> Int {
        let w = calendar.component(.weekday, from: date)
        return (w + 5) % 7 + 1
    }

    func scheduledWindowEnd(_ now: Date = Date()) -> Date? {
        guard let s = schedule else { return nil }
        for offset in [0, -1] {
            let start = startOfNight(dayOffset: offset, from: now, s)
            guard s.days.contains(isoWeekday(start)) else { continue }
            let end = start.addingTimeInterval(TimeInterval(s.durationMinutes * 60))
            if now >= start && now < end { return end }
        }
        return nil
    }

    /// Kilidin bittiği an (program ya da "şimdi uyu"), acil açmadan bağımsız.
    func lockUntil(_ now: Date = Date()) -> Date? {
        let manual = manualUntil.flatMap { $0 > now ? $0 : nil }
        let window = scheduledWindowEnd(now)
        switch (manual, window) {
        case let (m?, w?): return max(m, w)
        case let (m?, nil): return m
        case let (nil, w?): return w
        default: return nil
        }
    }

    func isEmergencyActive(_ now: Date = Date()) -> Bool {
        if let e = emergencyUntil, e > now { return true }
        return false
    }

    func isLockActive(_ now: Date = Date()) -> Bool {
        lockUntil(now) != nil && !isEmergencyActive(now)
    }

    func nightKey(_ date: Date = Date()) -> String {
        let end = schedule?.endMinutes ?? 7 * 60
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let d = m < end ? calendar.date(byAdding: .day, value: -1, to: date)! : date
        let p = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    // MARK: Kalkan (shield)

    /// Kilidi uygular. Uzantılardan da çağrılır.
    func applyShield() {
        guard let s = schedule else { return }
        let sel = selection
        managed.clearAllSettings()
        if s.blockMode == "all" {
            managed.shield.applicationCategories = .all(except: sel.applicationTokens)
            managed.shield.webDomainCategories = .all(except: sel.webDomainTokens)
        } else {
            managed.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
            managed.shield.applicationCategories = sel.categoryTokens.isEmpty
                ? nil : .specific(sel.categoryTokens)
            managed.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        }
        // Sıkı mod: kilit sırasında uygulama silinemez (Sleep Up dahil).
        managed.application.denyAppRemoval = s.strictMode ? true : nil
    }

    func clearShield() {
        managed.clearAllSettings()
    }

    // MARK: İstatistik

    func stat(_ key: String) -> [String: Int] {
        (defaults.dictionary(forKey: key) as? [String: Int]) ?? [:]
    }

    func bump(_ key: String, _ date: Date = Date()) {
        var m = stat(key)
        let k = nightKey(date)
        m[k, default: 0] += 1
        if m.count > 90 {
            for old in m.keys.sorted().prefix(m.count - 90) { m.removeValue(forKey: old) }
        }
        defaults.set(m, forKey: key)
    }

    func emergencyUsedTonight(_ now: Date = Date()) -> Int {
        stat("stats_emergency")[nightKey(now)] ?? 0
    }
}

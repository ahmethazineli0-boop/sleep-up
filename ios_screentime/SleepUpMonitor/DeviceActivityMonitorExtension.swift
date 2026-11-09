// Device Activity Monitor uzantısı.
// Uygulama kapalıyken bile sistem bu sınıfı programdaki anlarda çağırır;
// kalkanı açıp kapatan asıl yer burasıdır.

import DeviceActivity
import Foundation
import ManagedSettings

class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    private let store = SharedStore.shared

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .emergency:
            break // kalkanı uygulama zaten kaldırdı
        default:
            // Yeni bir gece başladı: önceki acil açma artık geçersiz.
            if activity.isNight { store.emergencyUntil = nil }
            if store.isLockActive(Date().addingTimeInterval(30)) { store.applyShield() }
        }
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        // Bitiş anında küçük saat farkları olabilir; 60 sn ileriye bakarak karar ver.
        let soon = Date().addingTimeInterval(60)
        if activity == .emergency {
            store.emergencyUntil = nil
            if store.lockUntil(soon) != nil { store.applyShield() }
            return
        }
        if activity == .manual, let m = store.manualUntil, m <= soon { store.manualUntil = nil }
        if store.lockUntil(soon) == nil { store.clearShield() }
    }

    /// Acil açma 15 dk'lık aralıkla kurulur; uyarı anı acil sürenin bittiği andır.
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        guard activity == .emergency else { return }
        store.emergencyUntil = nil
        if store.lockUntil(Date()) != nil { store.applyShield() }
    }
}

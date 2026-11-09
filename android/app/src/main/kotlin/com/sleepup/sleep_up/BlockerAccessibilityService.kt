package com.sleepup.sleep_up

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.view.accessibility.AccessibilityEvent

/**
 * Ön plana gelen uygulamayı izler; kilit saatinde engelli bir uygulama
 * açılırsa [LockActivity]'yi üstüne getirir.
 *
 * Yalnızca TYPE_WINDOW_STATE_CHANGED olayının paket adını okur;
 * ekran içeriğini okumaz (canRetrieveWindowContent=false).
 */
class BlockerAccessibilityService : AccessibilityService() {

    private lateinit var store: LockStore
    private val handler = Handler(Looper.getMainLooper())
    private var foregroundPkg: String? = null
    private var lastLaunchPkg: String? = null
    private var lastLaunchAt = 0L

    /** Kullanıcı kilit başlarken bir uygulamada kalırsa diye düzenli kontrol. */
    private val tick = object : Runnable {
        override fun run() {
            foregroundPkg?.let { maybeBlock(it, fromTick = true) }
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        store = LockStore(this)
        handler.postDelayed(tick, TICK_MS)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = event.packageName?.toString() ?: return
        // Klavye ve sistem kabuğu (bildirim paneli vb.) ön plandaki uygulamayı değiştirmez.
        if (pkg == "com.android.systemui" || pkg in store.inputMethodPackages()) return
        foregroundPkg = pkg
        maybeBlock(pkg, fromTick = false)
    }

    private fun maybeBlock(pkg: String, fromTick: Boolean) {
        if (pkg == packageName) return
        if (!store.shouldBlock(pkg)) return
        val now = System.currentTimeMillis()
        // Aynı uygulama için art arda açılmayı ve sayacı şişirmeyi önle.
        if (pkg == lastLaunchPkg && now - lastLaunchAt < 1500) return
        lastLaunchPkg = pkg
        lastLaunchAt = now
        if (!fromTick) store.countBlocked(now)
        startActivity(
            Intent(this, LockActivity::class.java)
                .putExtra(LockActivity.EXTRA_BLOCKED_PKG, pkg)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION
                )
        )
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        super.onDestroy()
    }

    companion object {
        private const val TICK_MS = 20_000L
    }
}

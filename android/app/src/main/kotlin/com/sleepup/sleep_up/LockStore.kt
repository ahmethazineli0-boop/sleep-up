package com.sleepup.sleep_up

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.provider.Settings
import android.telecom.TelecomManager
import android.view.inputmethod.InputMethodManager
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale

/**
 * Kilit kurallarının tek kaynağı. Flutter tarafı programı buraya yazar;
 * erişilebilirlik hizmeti, kilit ekranı ve alarmlar buradan okur.
 *
 * Günler: 1 = Pazartesi ... 7 = Pazar (Dart'taki DateTime.weekday ile aynı).
 * Bir gece başladığı güne aittir; bitiş saatinden önceki sabah saatleri
 * önceki geceye sayılır.
 */
class LockStore(private val ctx: Context) {

    private val prefs: SharedPreferences =
        ctx.getSharedPreferences("sleepup_native", Context.MODE_PRIVATE)

    data class Schedule(
        val startMinutes: Int,
        val endMinutes: Int,
        val days: Set<Int>,
        val windDownEnabled: Boolean,
        val windDownMinutes: Int,
        val strictMode: Boolean,
        val emergencyPerNight: Int,
        /** "selected": listedekileri kilitle. "all": her şeyi kilitle, listedekiler istisna. */
        val blockMode: String,
        val packages: Set<String>,
    ) {
        val durationMinutes: Int
            get() {
                val d = endMinutes - startMinutes
                return if (d > 0) d else d + 24 * 60
            }
    }

    // ---------- Program ----------

    fun saveSchedule(json: JSONObject) {
        prefs.edit().putString(K_SCHEDULE, json.toString()).apply()
    }

    fun schedule(): Schedule? {
        val raw = prefs.getString(K_SCHEDULE, null) ?: return null
        val j = JSONObject(raw)
        val days = mutableSetOf<Int>()
        j.optJSONArray("days")?.let { a -> for (i in 0 until a.length()) days.add(a.getInt(i)) }
        val pk = mutableSetOf<String>()
        j.optJSONArray("blockedPackages")?.let { a -> for (i in 0 until a.length()) pk.add(a.getString(i)) }
        return Schedule(
            startMinutes = j.optInt("startMinutes", 23 * 60),
            endMinutes = j.optInt("endMinutes", 7 * 60),
            days = days,
            windDownEnabled = j.optBoolean("windDownEnabled", true),
            windDownMinutes = j.optInt("windDownMinutes", 30),
            strictMode = j.optBoolean("strictMode", false),
            emergencyPerNight = j.optInt("emergencyPerNight", 1),
            blockMode = j.optString("blockMode", "selected"),
            packages = pk,
        )
    }

    /** Calendar.DAY_OF_WEEK (Pazar=1) → 1=Pazartesi..7=Pazar */
    private fun isoDay(c: Calendar): Int = ((c.get(Calendar.DAY_OF_WEEK) + 5) % 7) + 1

    private fun startOfNight(dayOffset: Int, now: Long, s: Schedule): Calendar =
        Calendar.getInstance().apply {
            timeInMillis = now
            add(Calendar.DAY_OF_YEAR, dayOffset)
            set(Calendar.HOUR_OF_DAY, s.startMinutes / 60)
            set(Calendar.MINUTE, s.startMinutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }

    /** Programdaki aktif pencerenin bitişi; pencere dışındaysa 0. */
    fun scheduledWindowEnd(now: Long = System.currentTimeMillis()): Long {
        val s = schedule() ?: return 0
        for (offset in intArrayOf(0, -1)) {
            val start = startOfNight(offset, now, s)
            if (isoDay(start) !in s.days) continue
            val end = start.timeInMillis + s.durationMinutes * 60_000L
            if (now >= start.timeInMillis && now < end) return end
        }
        return 0
    }

    /** Bir sonraki programlı başlangıç (8 gün içinde), yoksa 0. */
    fun nextStart(now: Long = System.currentTimeMillis()): Long {
        val s = schedule() ?: return 0
        for (offset in 0..7) {
            val start = startOfNight(offset, now, s)
            if (isoDay(start) in s.days && start.timeInMillis > now) return start.timeInMillis
        }
        return 0
    }

    // ---------- Anlık durum ----------

    var manualUntil: Long
        get() = prefs.getLong(K_MANUAL, 0)
        set(v) = prefs.edit().putLong(K_MANUAL, v).apply()

    var emergencyUntil: Long
        get() = prefs.getLong(K_EMERGENCY, 0)
        set(v) = prefs.edit().putLong(K_EMERGENCY, v).apply()

    /** Kilidin biteceği an (program ya da "şimdi uyu"); kilit yoksa 0. */
    fun lockUntil(now: Long = System.currentTimeMillis()): Long {
        val manual = manualUntil.takeIf { it > now } ?: 0
        return maxOf(manual, scheduledWindowEnd(now))
    }

    fun isLockActive(now: Long = System.currentTimeMillis()): Boolean =
        lockUntil(now) > now && emergencyUntil <= now

    // ---------- Hangi uygulama kilitlenir ----------

    fun shouldBlock(pkg: String): Boolean {
        if (!isLockActive()) return false
        val s = schedule() ?: return false
        if (pkg in alwaysAllowed()) return false
        if (pkg == SETTINGS_PKG) return s.strictMode
        return when (s.blockMode) {
            "all" -> pkg !in s.packages
            else -> pkg in s.packages
        }
    }

    private var allowCache: Set<String>? = null
    private var allowCacheAt = 0L

    /** Telefon, saat, acil durum, klavye, ana ekran ve Sleep Up her zaman açık. */
    fun alwaysAllowed(): Set<String> {
        val now = System.currentTimeMillis()
        allowCache?.let { if (now - allowCacheAt < 60_000) return it }
        val set = mutableSetOf(
            ctx.packageName,
            "android", "com.android.systemui",
            "com.android.phone", "com.android.server.telecom", "com.android.emergency",
            "com.google.android.dialer", "com.android.dialer", "com.samsung.android.dialer",
            "com.google.android.deskclock", "com.android.deskclock", "com.sec.android.app.clockpackage",
            "com.android.incallui",
        )
        // Varsayılan ana ekran (başlatıcı)
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        ctx.packageManager.queryIntentActivities(home, 0).forEach { set.add(it.activityInfo.packageName) }
        // Varsayılan arama uygulaması
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            (ctx.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager)?.defaultDialerPackage?.let { set.add(it) }
        }
        // Klavyeler (yazarken kilit ekranı açılmasın)
        set.addAll(inputMethodPackages())
        allowCache = set
        allowCacheAt = now
        return set
    }

    private var imeCache: Set<String> = emptySet()
    private var imeCacheAt = 0L

    fun inputMethodPackages(): Set<String> {
        val now = System.currentTimeMillis()
        if (now - imeCacheAt < 60_000) return imeCache
        imeCache = (ctx.getSystemService(Context.INPUT_METHOD_SERVICE) as? InputMethodManager)
            ?.enabledInputMethodList?.map { it.packageName }?.toSet() ?: emptySet()
        imeCacheAt = now
        return imeCache
    }

    // ---------- Acil açma ----------

    fun emergencyUsedTonight(now: Long = System.currentTimeMillis()): Int =
        statMap(K_STAT_EMERGENCY).optInt(nightKey(now), 0)

    /** Hak varsa [minutes] dakikalığına açar. */
    fun useEmergency(minutes: Int, now: Long = System.currentTimeMillis()): Boolean {
        val s = schedule() ?: return false
        if (!isLockActive(now)) return false
        if (emergencyUsedTonight(now) >= s.emergencyPerNight) return false
        emergencyUntil = now + minutes * 60_000L
        bump(K_STAT_EMERGENCY, now)
        return true
    }

    // ---------- İstatistik ----------

    fun countBlocked(now: Long = System.currentTimeMillis()) = bump(K_STAT_BLOCKED, now)

    fun statMap(key: String): JSONObject =
        prefs.getString(key, null)?.let { JSONObject(it) } ?: JSONObject()

    private fun bump(key: String, now: Long) {
        val m = statMap(key)
        val k = nightKey(now)
        m.put(k, m.optInt(k, 0) + 1)
        // 90 geceden eskileri temizle
        val keys = m.keys().asSequence().toList().sorted()
        if (keys.size > 90) keys.take(keys.size - 90).forEach { m.remove(it) }
        prefs.edit().putString(key, m.toString()).apply()
    }

    fun nightKey(now: Long): String {
        val end = schedule()?.endMinutes ?: (7 * 60)
        val c = Calendar.getInstance().apply { timeInMillis = now }
        val m = c.get(Calendar.HOUR_OF_DAY) * 60 + c.get(Calendar.MINUTE)
        if (m < end) c.add(Calendar.DAY_OF_YEAR, -1)
        return String.format(
            Locale.US, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
        )
    }

    // ---------- İzin ----------

    fun accessibilityEnabled(): Boolean {
        val enabled = Settings.Secure.getString(
            ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        val me = "${ctx.packageName}/${BlockerAccessibilityService::class.java.name}"
        val meShort = "${ctx.packageName}/.${BlockerAccessibilityService::class.java.simpleName}"
        return enabled.split(':').any { it.equals(me, true) || it.equals(meShort, true) }
    }

    companion object {
        private const val K_SCHEDULE = "schedule"
        private const val K_MANUAL = "manual_until"
        private const val K_EMERGENCY = "emergency_until"
        const val K_STAT_BLOCKED = "stats_blocked"
        const val K_STAT_EMERGENCY = "stats_emergency"
        const val SETTINGS_PKG = "com.android.settings"
    }
}

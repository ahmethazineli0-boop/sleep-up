package com.sleepup.sleep_up

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Flutter ↔ Android köprüsü: kanal 'sleepup/blocker'. */
class MainActivity : FlutterActivity() {

    private val store by lazy { LockStore(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sleepup/blocker")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getPermissions" -> result.success(
                            mapOf(
                                "accessibility" to store.accessibilityEnabled(),
                                "notifications" to notificationsEnabled(),
                            )
                        )
                        "requestPermission" -> result.success(request(call.argument<String>("permission")))
                        "getInstalledApps" -> result.success(installedApps())
                        "getSelectionCount" -> result.success(0)
                        "applySchedule" -> {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any?>
                            store.saveSchedule(JSONObject(args))
                            WindDown.schedule(this)
                            result.success(null)
                        }
                        "startNow" -> {
                            val until = (call.argument<Number>("untilMillis"))?.toLong() ?: 0L
                            if (until > System.currentTimeMillis()) {
                                store.manualUntil = until
                                store.emergencyUntil = 0
                            }
                            result.success(store.accessibilityEnabled())
                        }
                        "emergencyUnlock" -> {
                            val minutes = call.argument<Int>("minutes") ?: 5
                            result.success(store.useEmergency(minutes))
                        }
                        "getStatus" -> {
                            val now = System.currentTimeMillis()
                            result.success(
                                mapOf(
                                    "lockActive" to store.isLockActive(now),
                                    "lockUntilMillis" to store.lockUntil(now),
                                    "emergencyUntilMillis" to store.emergencyUntil,
                                    "emergencyUsedTonight" to store.emergencyUsedTonight(now),
                                )
                            )
                        }
                        "getStats" -> result.success(
                            mapOf(
                                "blocked" to toMap(store.statMap(LockStore.K_STAT_BLOCKED)),
                                "emergency" to toMap(store.statMap(LockStore.K_STAT_EMERGENCY)),
                            )
                        )
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }

    private fun toMap(j: JSONObject): Map<String, Int> =
        j.keys().asSequence().associateWith { j.optInt(it, 0) }

    private fun notificationsEnabled(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return true
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return nm.areNotificationsEnabled()
    }

    private fun request(permission: String?): Boolean {
        when (permission) {
            "accessibility" -> startActivity(
                Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            "notifications" -> {
                if (Build.VERSION.SDK_INT >= 33 &&
                    checkSelfPermission("android.permission.POST_NOTIFICATIONS") != PackageManager.PERMISSION_GRANTED
                ) {
                    requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 42)
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startActivity(
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                            .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    )
                } else {
                    startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    )
                }
            }
            else -> return false
        }
        return true
    }

    private fun installedApps(): List<Map<String, String>> {
        val pm = packageManager
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        @Suppress("DEPRECATION")
        val list = pm.queryIntentActivities(launcher, 0)
        val allowed = store.alwaysAllowed()
        return list
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { (pkg, _) -> pkg !in allowed }
            .distinctBy { it.first }
            .map { (pkg, label) -> mapOf("package" to pkg, "label" to label) }
    }
}

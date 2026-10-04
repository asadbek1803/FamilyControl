package com.familycontrol.family_control_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.accessibility.AccessibilityEvent

/**
 * Oilaviy nazoratning ANDROID QISMIDAGI ASOSIY HIMOYA.
 *
 * Vazifa: "Sozlamalar" va ilova o'rnatish ekranlarini PIN kod kirgandan oldin
 * ochib bo'lmaydigan qilish. Bu Android AccessibilityService API si orqali
 * ommaviy va hujjatlashtirilgan usul — foydalanuvchi sozlamalarda ilovani
 * ko'rib, yoqishini tasdiqlaydi.
 *
 * DIQQAT: bu xizmat HECH QANDAY shaxsiy ma'lumot (SMS, chat yozishmalari,
 * ekrandagi matn) yig'maydi va o'qimaydi. Atolgan ota-ona o'z farzandining
 * qurilmasini nazorat qilish uchun ishlatiladi.
 */
class ChildAccessibilityService : AccessibilityService() {

    companion object {
        const val EXTRA_REQUIRE_PIN = "require_pin"

        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY_CHILD_MODE = "flutter.is_child_mode"
        private const val KEY_UNLOCKED_UNTIL = "flutter.unlocked_until"

        private const val PKG_SETTINGS = "com.android.settings"
        private const val PKG_INSTALLER = "com.google.android.packageinstaller"
        private const val PKG_SAMSUNG_INSTALLER = "com.samsung.android.app.spage"

        /** Takroriy `startActivity` chaqiruvlarini bostirish uchun */
        private const val MIN_REDIRECT_INTERVAL_MS = 2000L

        /** Batareya holati tekshiriladi (soatda bir marta) */
        private const val BATTERY_CHECK_INTERVAL_MS = 60L * 60L * 1000L

        /** Ota-onaga xabar beriladigan qullab qolish darajasi (%) */
        private const val BATTERY_LOW_PERCENT = 20

        /** Xabar berilgan eng past foiz — har gal qayta yubormaslik uchun */
        private const val BATTERY_REPORTED_BELOW_PERCENT = 15

        private const val STATE_BATTERY_LAST_CHECK = "battery_last_check"
        private const val STATE_BATTERY_REPORTED_AT = "battery_reported_at"
    }

    private var prefs: SharedPreferences? = null
    private var lastRedirectAt = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        val packageName = event?.packageName?.toString() ?: return
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

        // Batareya holati fon rejimida tekshiriladi — ota-ona har doim
        // batareya haqida xabardor bo'lishi uchun.
        reportBatteryIfLow()

        if (!isProtectedScreen(packageName)) return
        if (!isChildMode()) return

        val now = System.currentTimeMillis()
        if (now <= unlockedUntil()) return // PIN to'g'ri kiritilgan, vaqt hali bor

        if (now - lastRedirectAt < MIN_REDIRECT_INTERVAL_MS) return
        lastRedirectAt = now

        // 1) Sozlamalardan chiqamiz
        performGlobalAction(GLOBAL_ACTION_HOME)

        // 2) PIN ekranini ko'rsatamiz
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                putExtra(EXTRA_REQUIRE_PIN, true)
            }
        )
    }

    /**
     * Batareya past bo'lsa ota-onaga xabar beradi. Soatda bir marta tekshiriladi
     * va faqat yangi eng past daraja (15% dan past) bo'lganda xabar yuboriladi —
     * aks holda har oyna o'zgarishida bir xil xabar yuborilardi.
     */
    private fun reportBatteryIfLow() {
        val p = prefs ?: return
        val now = System.currentTimeMillis()
        val lastCheck = p.getLong(STATE_BATTERY_LAST_CHECK, 0L)
        if (now - lastCheck < BATTERY_CHECK_INTERVAL_MS) return
        p.edit().putLong(STATE_BATTERY_LAST_CHECK, now).apply()

        val manager = getSystemService(Context.BATTERY_SERVICE) as? android.os.BatteryManager ?: return
        val percent = manager.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
        if (percent <= 0 || percent > BATTERY_LOW_PERCENT) return
        if (percent <= BATTERY_REPORTED_BELOW_PERCENT &&
            p.getBoolean(STATE_BATTERY_REPORTED_AT, false)
        ) {
            return
        }

        p.edit().putBoolean(STATE_BATTERY_REPORTED_AT, true).apply()
        DeviceEventReporter.report(
            this,
            DeviceEventReporter.EVENT_BATTERY_LOW,
            "🔋 Batareya $percent% ga tushdi. Quyib qo'yish ehtimoli bor.",
            mapOf("percent" to percent),
        )
    }

    private fun isProtectedScreen(packageName: String): Boolean =
        packageName == PKG_SETTINGS ||
            packageName == PKG_INSTALLER ||
            packageName == PKG_SAMSUNG_INSTALLER

    private fun isChildMode(): Boolean = prefs?.getBoolean(KEY_CHILD_MODE, false) == true

    /**
     * Dart'da `setLong` yo'q, `setInt` ishlatiladi — Android plagini uni ichkarida
     * `putLong` bilan saqlaydi, shuning uchun bu yerda `getLong` to'g'ri tip.
     * Ikkala tomon bir xil tipda bo'lishi SHART, aks holda ClassCastException
     * berib, PIN ekrani hech qachon ochilmay qoladi.
     */
    private fun unlockedUntil(): Long = prefs?.getLong(KEY_UNLOCKED_UNTIL, 0L) ?: 0L

    override fun onInterrupt() {
        // Xizmat tizim tomonidan to'xtatilganda chaqiriladi.
    }
}

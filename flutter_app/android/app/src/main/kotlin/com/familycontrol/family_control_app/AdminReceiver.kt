package com.familycontrol.family_control_app

import android.app.admin.DeviceAdminReceiver
import android.app.admin.DevicePolicyManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import android.widget.Toast

/**
 * Qurilma ma'muri (Device Admin) qabul qilingachan ilovani o'chirishga to'xtatish
 * IMKONI YO'Q — Android 5.0 dan boshlab oddiy (non-device-owner) ilova o'zini
 * o'chirishdan himoyalanmaydi. `onDisableRequested` faqat ogohlantirish matni
 * qaytaradi; foydalanuvchi "OK" bosib o'chiraveradi.
 *
 * Shu sababli haqiqiy himoya [ChildAccessibilityService] orqali "Sozlamalar"ni
 * PIN bilan bloklashda. Device Admin esa ikki qo'shimcha vazifani bajaradi:
 *   1) `force-lock` — ma'mur bekor qilinish aurasida ekranni bloklash;
 *   2) `wipe-data` — ma'mur bekor qilingandan keyin qurilma ma'lumotini tozalash.
 */
class AdminReceiver : DeviceAdminReceiver() {

    override fun onEnabled(context: Context, intent: Intent) {
        Log.i(TAG, "Device Admin faollashtirildi")
        Toast.makeText(context, "FamilyControl himoyasi yoqilgan", Toast.LENGTH_SHORT).show()
        DeviceEventReporter.report(
            context,
            DeviceEventReporter.EVENT_ADMIN_ENABLED,
            "🛡️ Qurilma himoyasi yoqildi (Device Admin faollashtirildi).",
        )
    }

    /**
     * DIQQAT: bu FAQAT ogohlantirish matni qaytaradi, bekor qilishni to'xtatmaydi.
     * Shu bilan birga admin hali faol bo'lgani uchun ekranni bloklab qo'yamiz,
     * shunda foydalanuvchi PIN kiritmasidan o'chiqolmaydi.
     */
    override fun onDisableRequested(context: Context, intent: Intent): CharSequence {
        lockNow(context)
        return context.getString(R.string.admin_disable_warning)
    }

    override fun onDisabled(context: Context, intent: Intent) {
        Log.i(TAG, "Device Admin bekor qilindi")

        // Bu eng muhim hodisa: himoya o'chirildi. Ota-onaga Telegram orqali
        // xabar yuboriladi. Bot tokeni FAQAT serverda — shuning uchun bu
        // yerda faqat serverga murojat boriladi.
        DeviceEventReporter.report(
            context,
            DeviceEventReporter.EVENT_ADMIN_DISABLED,
            "⚠️ Qurilma himoyasi O'CHIRILDI! Endi ilovalar bloklanmaydi va " +
                "boshqaruv ota-onaga ulanib qolmaydi.",
        )

        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager
        if (dpm == null) {
            Log.w(TAG, "DevicePolicyService topilmadi")
            return
        }

        // DIQQAT: `wipeData()` (parametrsiz) API 34 da OLIB TASHLANDI, o'rniga
        // `wipeData(int flags, CharSequence reason)` keldi. Eski API'larda bu
        // umuman mavjud emas — shuning uchun versiyani tekshiramiz.
        // Bundan tashqari, API 24+ dan boshlab wipeData faqat device/profile
        // owner uchun ishlaydi; oddiy admin bo'lganimizda SecurityException
        // keladi — shuning uchun ham try/catch.
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            Log.w(TAG, "wipeData faqat API 34+ da mavjud, bu qurilmada bajarilmadi")
            return
        }
        try {
            dpm.wipeData(0, context.getString(R.string.admin_wipe_reason))
        } catch (e: Exception) {
            Log.w(TAG, "wipeData bajarilmadi (oddiy admin uchun mumkin emas): ${e.message}")
        }
        Toast.makeText(context, "FamilyControl o'chirildi", Toast.LENGTH_SHORT).show()
    }

    private fun lockNow(context: Context) {
        val dpm = context.getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return
        try {
            dpm.lockNow()
        } catch (e: Exception) {
            Log.w(TAG, "lockNow ishga tushmadi: ${e.message}")
        }
    }

    companion object {
        private const val TAG = "FamilyControl_Admin"
    }
}

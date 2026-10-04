package com.familycontrol.family_control_app

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.familycontrol/accessibility"
        private const val EXTRA_REQUIRE_PIN = ChildAccessibilityService.EXTRA_REQUIRE_PIN
        private const val REQUEST_DEVICE_ADMIN = 1001
    }

    /**
     * AccessibilityService ilovani to'g'ridan-to'g'ri ishga tushirishi mumkin, holatda
     * jarayon o'ldirilgan bo'lishi ehtimoli bor. Shuning uchun `require_pin` ni
     * intent'dan BIRTA bor o'qib, bayroqda saqlaymiz. Dart tomon `consumePinRoute`
     * orqali uni oladi (ilova qayta ishga tushganda).
     */
    @Volatile
    private var pendingPinRoute = false

    private var pendingAdminResult: MethodChannel.Result? = null

    private fun channel(): MethodChannel? =
        flutterEngine?.let { MethodChannel(it.dartExecutor.binaryMessenger, CHANNEL) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAccessibilitySettings" -> {
                    startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                "isDeviceAdminEnabled" -> result.success(isDeviceAdminEnabled())

                // So Cold-start holat uchun: ilova qayta o'tganda bayroqni oladi va tozalaydi.
                "consumePinRoute" -> {
                    val value = pendingPinRoute
                    pendingPinRoute = false
                    result.success(value)
                }

                "requestDeviceAdmin" -> requestDeviceAdmin(result)

                // Native tarafga server manzili. Faqat ilova o'rnatilgan koddan
                // (ApiConstants.baseUrl) keladi — Telegram yoki boshqa tashqi
                // kanaldan o'zgartirilmaydi.
                "saveServerBaseUrl" -> {
                    val url = call.argument<String>("baseUrl")
                    if (url.isNullOrBlank()) {
                        result.error("INVALID_URL", "baseUrl bo'sh", null)
                    } else {
                        DeviceEventReporter.saveBaseUrl(this, url.trimEnd('/'))
                        result.success(true)
                    }
                }

                // Qurilma tokeni Dart'da `FlutterSecureStorage` da saqlanadi.
                // BroadcastReceiver'lar (masalan Device Admin o'chirilganda)
                // Dart'siz ishlashi kerakligi uchun bizga ham kerak bo'ladi.
                "saveDeviceCredentials" -> {
                    val deviceId = call.argument<String>("deviceId")
                    val token = call.argument<String>("token")
                    if (deviceId.isNullOrBlank() || token.isNullOrBlank()) {
                        result.error("INVALID_CREDENTIALS", "deviceId yoki token bo'sh", null)
                    } else {
                        DeviceEventReporter.saveCredentials(this, deviceId, token)
                        result.success(true)
                    }
                }

                "clearDeviceCredentials" -> {
                    DeviceEventReporter.clearCredentials(this)
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun requestDeviceAdmin(result: MethodChannel.Result) {
        if (isDeviceAdminEnabled()) {
            result.success(true)
            return
        }
        if (pendingAdminResult != null) {
            result.error("IN_PROGRESS", "Device Admin dialogi allaqachon ochiq", null)
            return
        }

        pendingAdminResult = result
        try {
            val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
            intent.putExtra(
                DevicePolicyManager.EXTRA_DEVICE_ADMIN,
                ComponentName(this, AdminReceiver::class.java),
            )
            intent.putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                getString(R.string.device_admin_explanation),
            )
            startActivityForResult(intent, REQUEST_DEVICE_ADMIN)
        } catch (e: Exception) {
            pendingAdminResult = null
            result.error("ADMIN_DIALOG_FAILED", e.message, null)
        }
    }

    private fun isDeviceAdminEnabled(): Boolean {
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as? DevicePolicyManager ?: return false
        return dpm.isAdminActive(ComponentName(this, AdminReceiver::class.java))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingPinRoute = intent?.getBooleanExtra(EXTRA_REQUIRE_PIN, false) == true
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.getBooleanExtra(EXTRA_REQUIRE_PIN, false)) {
            pendingPinRoute = true
            // Bayroqni olib bo'lgach extra'ni olib tashlaymiz. Aks holda
            // konfiguratsiya o'zgarganda Activity qayta yaratilib, `onCreate`
            // da `intent` dan qayta o'qilib, allaqach ochiq PIN ekranini
            // yana ochib yuborardi.
            intent.removeExtra(EXTRA_REQUIRE_PIN)
            // Ilova allaqachon ishga tushgan bo'lsa, darhol Dart'ga xabar beramiz.
            channel()?.invokeMethod("pinLockRequested", null)
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != REQUEST_DEVICE_ADMIN) return

        val result = pendingAdminResult ?: return
        pendingAdminResult = null
        // resultCode == RESULT_OK -> foydalanuvchi "Faollashtirish"ni bosgan.
        // Endi Dart aniq natijani biladi va keyingi ruxsat oynasini o'zi ochadi.
        result.success(isDeviceAdminEnabled())
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        pendingAdminResult?.error("ENGINE_DETACHED", "Flutter engine yopildi", null)
        pendingAdminResult = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}

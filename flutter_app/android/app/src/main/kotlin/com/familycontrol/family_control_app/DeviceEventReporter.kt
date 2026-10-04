package com.familycontrol.family_control_app

import android.content.Context
import android.util.Log
import org.json.JSONObject
import java.io.BufferedReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors

/**
 * Qurilma hodisalarini serverga yuboradi.
 *
 * Nima uchun native (Kotlin) tomonda kerak: ba'zi hodisalarni Flutter/Dart
 * jarayoniga ulab bo'lmaydi. Masalan, `onDisabled` — ya'ni foydalanuvchi
 * "Device Admin"ni o'chirgan paytda — BroadcastReceiver ichida ishlaydi va
 * o'sha paytda ilova processi o'lik bo'lishi mumkin. Dart chaqiruvi
 * ishlamaydi, lekin shu modul mustaqil ravishda ishlaydi.
 *
 * XAVFSIZLIK: shu yerda hech qachon Telegram bot tokeni yoki ota-onaning
 * chat ID si saqlanmaydi. Bot tokeni FAQAT serverda; bu modul faqat
 * `device_token` bilan `POST /devices/events/` ga murodat yuboradi, Telegram
 * ga yetkazishni esa server bajaradi.
 */
object DeviceEventReporter {

    private const val TAG = "FamilyControl_Events"
    private const val PREFS = "familycontrol_device"
    private const val KEY_DEVICE_ID = "native_device_id"
    private const val KEY_DEVICE_TOKEN = "native_device_token"
    private const val KEY_BASE_URL = "server_base_url"

    private const val CONNECT_TIMEOUT_MS = 8_000
    private const val READ_TIMEOUT_MS = 8_000

    /** BroadcastReceiver'lar parallel yuklamasligi uchun bitta executor. */
    private val executor = Executors.newSingleThreadExecutor()

    fun saveCredentials(context: Context, deviceId: String, token: String) {
        prefs(context).edit()
            .putString(KEY_DEVICE_ID, deviceId)
            .putString(KEY_DEVICE_TOKEN, token)
            .apply()
    }

    fun clearCredentials(context: Context) {
        prefs(context).edit()
            .remove(KEY_DEVICE_ID)
            .remove(KEY_DEVICE_TOKEN)
            .apply()
    }

    /**
     * Server manzilini saqlaydi. Uni Dart ilova ishga tushganda yuboradi, chunki
     * manzil Dart (`ApiConstants.baseUrl`) da aniqlanadi.
     *
     * DIQQAT: bu manzil Telegram orqali yoki boshqa tashqi kanaldan
     * o'zgartirilmaydi — faqat ilova o'rnatilgan kod orqali.
     */
    fun saveBaseUrl(context: Context, baseUrl: String) {
        prefs(context).edit().putString(KEY_BASE_URL, baseUrl).apply()
    }

    /**
     * Hodisani serverga yuborishga urinadi. Bloklovchi emas — muvaffaqiyatsiz
     * bo'lsa jimgina loglaydi, chunki bu har doim fon rejimida ishlaydi.
     *
     * @param data faqat texnik ma'lumot (batareya foizi, paket nomi). Boshqa
     *   ilovalarning xabar matni yoki chat yozishmalari bu yerda YUBORILMAYDI.
     */
    fun report(context: Context, eventType: String, message: String, data: Map<String, Any?> = emptyMap()) {
        val appContext = context.applicationContext
        executor.execute {
            try {
                post(appContext, eventType, message, data)
            } catch (e: Exception) {
                Log.w(TAG, "Hodisa yuborilmadi ($eventType): ${e.message}")
            }
        }
    }

    private fun post(context: Context, eventType: String, message: String, data: Map<String, Any?>) {
        val p = prefs(context)
        val deviceId = p.getString(KEY_DEVICE_ID, null) ?: run {
            Log.i(TAG, "Qurilma tokeni yo'q — hodisa yuborilmaydi ($eventType)")
            return
        }
        val token = p.getString(KEY_DEVICE_TOKEN, null) ?: return
        val baseUrl = p.getString(KEY_BASE_URL, null) ?: return

        val endpoint = "$baseUrl$PATH_EVENTS"
        val body = JSONObject().apply {
            put("event_type", eventType)
            put("message", message)
            put("data", JSONObject(data))
        }.toString()

        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = CONNECT_TIMEOUT_MS
            readTimeout = READ_TIMEOUT_MS
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("Authorization", "DeviceBearer $deviceId:$token")
        }

        try {
            connection.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            val code = connection.responseCode
            if (code in 200..299) {
                Log.i(TAG, "Hodisa yuborildi: $eventType")
            } else {
                val err = connection.errorStream?.bufferedReader()?.use(BufferedReader::readText)
                Log.w(TAG, "Server $code qaytardi ($eventType): ${err?.take(200)}")
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    /**
     * `ApiConstants.baseUrl` ning o'ziga qo'shiladi. Unda `/api/v1` allaqach
     * bor (masalan `http://10.0.2.2:8000/api/v1`), shuning uchun bu yo'l
     * nisbiy ko'rinishda.
     */
    private const val PATH_EVENTS = "/devices/events/"

    /** Serverdagi `DeviceEvent.EVENT_*` qiymatlariga mos kelishi SHART. */
    const val EVENT_ADMIN_DISABLED = "admin_disabled"
    const val EVENT_ADMIN_ENABLED = "admin_enabled"
    const val EVENT_BATTERY_LOW = "battery_low"
    const val EVENT_APP_BLOCKED = "app_blocked"
    const val EVENT_APP_UNBLOCKED = "app_unblocked"
}
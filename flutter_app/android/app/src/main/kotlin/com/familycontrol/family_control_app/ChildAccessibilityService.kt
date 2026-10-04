package com.familycontrol.family_control_app

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import android.util.Log

class ChildAccessibilityService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return

        // 1. PIN QULFLASH MANTIG'I (Sozlamalar va o'chirish uchun)
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            if (packageName == "com.android.settings" || packageName == "com.google.android.packageinstaller") {
                val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                val isChildMode = prefs.getBoolean("flutter.is_child_mode", false)
                
                if (isChildMode) {
                    val unlockedUntil = prefs.getLong("flutter.unlocked_until", 0L)
                    val currentTime = System.currentTimeMillis()
                    
                    if (currentTime > unlockedUntil) {
                        performGlobalAction(GLOBAL_ACTION_HOME)
                        val intent = Intent(this, MainActivity::class.java)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        intent.putExtra("require_pin", true)
                        startActivity(intent)
                    }
                }
            }
        }

        // 2. CHROME VA IJTIMOIY TARMOQLARNI KUZATISH MANTIG'I
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            // Chrome'dan veb manzilni (URL) o'qish
            if (packageName == "com.android.chrome") {
                val nodeInfo = event.source
                if (nodeInfo != null) {
                    val urlNodes = nodeInfo.findAccessibilityNodeInfosByViewId("com.android.chrome:id/url_bar")
                    if (urlNodes.isNotEmpty()) {
                        val url = urlNodes[0].text?.toString()
                        if (url != null && url.startsWith("http")) {
                            Log.d("FamilyControl_Log", "Bola Chrome'da kirdi: $url")
                            // TODO: Buni Flutter bazasiga yozish kerak
                        }
                    }
                }
            }

            // Telegram, Instagram va WhatsApp dagi xabarlarni o'qish
            if (packageName == "org.telegram.messenger" || packageName == "com.instagram.android" || packageName == "com.whatsapp") {
                val textList = event.text
                if (textList != null && textList.isNotEmpty()) {
                    val text = textList.joinToString(" ")
                    if (text.isNotBlank()) {
                        Log.d("FamilyControl_Log", "Ijtimoiy tarmoq ($packageName): $text")
                        // TODO: Buni ham orqa fonda saqlab serverga (sync) jo'natiladi
                    }
                }
            }
        }
    }

    override fun onInterrupt() {
        // Xizmat to'xtatilganda
    }
}

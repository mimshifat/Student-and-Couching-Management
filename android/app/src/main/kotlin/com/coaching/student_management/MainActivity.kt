package com.coaching.student_management

import android.content.Context
import android.os.Build
import android.telephony.SmsManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.coaching.student_management/sms"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "sendSms" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    val simSlot = call.argument<Int>("simSlot") // 0 for SIM 1, 1 for SIM 2, null for default

                    if (phone.isNullOrEmpty() || message.isNullOrEmpty()) {
                        result.error("INVALID_ARGUMENTS", "Phone and message are required", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val normalizedPhone = convertBengaliDigits(phone)
                        val cleanPhone = normalizedPhone.replace(Regex("[^0-9+]"), "")
                        val digitsOnly = cleanPhone.replace(Regex("[^0-9]"), "")
                        if (digitsOnly.length < 5) {
                            result.error("INVALID_PHONE", "Phone number is too short or invalid", null)
                            return@setMethodCallHandler
                        }

                        // Validate SIM slot if specified
                        if (simSlot != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                            try {
                                val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                                val activeList = subscriptionManager?.activeSubscriptionInfoList
                                if (activeList != null && activeList.isNotEmpty()) {
                                    val hasSlotInList = activeList.any { it.simSlotIndex == simSlot || it.simSlotIndex == simSlot + 1 } || (activeList.size > simSlot)
                                    var hasSlotInSubIds = false
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                                        val subIds = subscriptionManager.getSubscriptionIds(simSlot)
                                        hasSlotInSubIds = subIds != null && subIds.isNotEmpty()
                                    }
                                    if (!hasSlotInList && !hasSlotInSubIds) {
                                        result.error("SIM_NOT_FOUND", "SIM ${simSlot + 1} is not active or not inserted", null)
                                        return@setMethodCallHandler
                                    }
                                }
                            } catch (e: Throwable) {
                                // If reading active list fails, continue safely
                            }
                        }

                        val smsManager = getSmsManager(this, simSlot)
                        if (smsManager == null) {
                            result.error("SMS_SERVICE_UNAVAILABLE", "SMS service is not available on this device", null)
                            return@setMethodCallHandler
                        }

                        val parts = smsManager.divideMessage(message)
                        if (parts.isNullOrEmpty()) {
                            result.error("EMPTY_MESSAGE", "Message body is empty", null)
                            return@setMethodCallHandler
                        }

                        smsManager.sendMultipartTextMessage(cleanPhone, null, parts, null, null)
                        result.success(true)
                    } catch (e: Throwable) {
                        result.error("SMS_FAILED", e.localizedMessage ?: "Unknown native error", null)
                    }
                }
                "getSimInfo" -> {
                    try {
                        val simInfo = getSimDeviceInfo(this)
                        result.success(simInfo)
                    } catch (e: Throwable) {
                        result.success(mapOf(
                            "maxSlots" to 2,
                            "activeSlots" to listOf(0, 1),
                            "carriers" to emptyMap<String, String>()
                        ))
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getCarrierFromMccMnc(mccMnc: String?): String? {
        if (mccMnc.isNullOrBlank()) return null
        val code = mccMnc.trim()
        return when {
            // Bangladesh Operators (MCC 470)
            code.startsWith("47001") -> "Grameenphone"
            code.startsWith("47002") -> "Robi"
            code.startsWith("47003") -> "Banglalink"
            code.startsWith("47004") -> "Teletalk"
            code.startsWith("47005") -> "Citycell"
            code.startsWith("47007") -> "Airtel"
            code.startsWith("47009") -> "Ollo"
            // India (MCC 404, 405) - Common border/roaming SIMs
            code.startsWith("404") || code.startsWith("405") -> {
                when {
                    code.contains("jio", ignoreCase = true) -> "Jio"
                    else -> "India SIM"
                }
            }
            else -> null
        }
    }

    private fun isGenericCarrierName(name: String?): Boolean {
        if (name.isNullOrBlank()) return true
        val lower = name.lowercase().trim()
        return lower.matches(Regex("^(sim|card|slot)\\s*[0-9]*$")) || lower.matches(Regex("^[0-9]+$"))
    }

    private fun cleanBrandName(rawName: String?, mccMnc: String?): String? {
        val lower = rawName?.lowercase()?.trim() ?: ""

        // Check explicit brands by name first
        if (lower.contains("skitto")) {
            return "Skitto"
        }
        if (lower.contains("airtel") || lower.contains("robi-airtel") || lower.contains("airtel-robi") || lower.contains("airtel bd")) {
            return "Airtel"
        }
        if (lower.contains("robi")) {
            return "Robi"
        }
        if (lower.contains("grameenphone") || lower.contains("grameen") || lower == "gp" || lower.startsWith("gp ") || lower.endsWith(" gp")) {
            return "Grameenphone"
        }
        if (lower.contains("banglalink") || lower == "bl" || lower.startsWith("bl ") || lower.endsWith(" bl")) {
            return "Banglalink"
        }
        if (lower.contains("teletalk")) {
            return "Teletalk"
        }
        if (lower.contains("citycell")) {
            return "Citycell"
        }

        // If rawName didn't match known brand, check MCC/MNC
        val fromMcc = getCarrierFromMccMnc(mccMnc)
        if (fromMcc != null) {
            return fromMcc
        }

        // If rawName is a valid non-generic name, clean trailing generation specs like " 4G"
        if (!rawName.isNullOrEmpty() && !isGenericCarrierName(rawName)) {
            return rawName.replace(Regex("(?i)\\s+(4g|5g|3g|lte|gsm)$"), "").trim()
        }

        return null
    }

    private fun resolveCarrierName(
        telephonyManager: TelephonyManager?,
        info: android.telephony.SubscriptionInfo
    ): String {
        val carrierName = info.carrierName?.toString()?.trim()
        val displayName = info.displayName?.toString()?.trim()

        var subSimOpName: String? = null
        var subNetOpName: String? = null
        var subMccMnc: String? = null

        // Try TelephonyManager for this subscription (API 24+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N && telephonyManager != null) {
            try {
                val subTm = telephonyManager.createForSubscriptionId(info.subscriptionId)
                subSimOpName = subTm.simOperatorName?.trim()
                subNetOpName = subTm.networkOperatorName?.trim()
                subMccMnc = subTm.simOperator?.trim() ?: subTm.networkOperator?.trim()
            } catch (_: Throwable) {}
        }

        // Try MCC/MNC from SubscriptionInfo
        var infoMccMnc: String? = null
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val mcc = info.mccString ?: ""
                val mnc = info.mncString ?: ""
                if (mcc.isNotEmpty() && mnc.isNotEmpty()) infoMccMnc = "$mcc$mnc"
            } else {
                @Suppress("DEPRECATION")
                val mcc = info.mcc
                @Suppress("DEPRECATION")
                val mnc = info.mnc
                if (mcc > 0) infoMccMnc = String.format("%03d%02d", mcc, mnc)
            }
        } catch (_: Throwable) {}

        val effectiveMccMnc = infoMccMnc ?: subMccMnc ?: if (info.simSlotIndex == 0) telephonyManager?.simOperator else null

        // 1. Try cleaning brand name from carrierName & displayName
        cleanBrandName(carrierName, effectiveMccMnc)?.let { return it }
        cleanBrandName(displayName, effectiveMccMnc)?.let { return it }

        // 2. Try sub TelephonyManager operator names
        cleanBrandName(subSimOpName, effectiveMccMnc)?.let { return it }
        cleanBrandName(subNetOpName, effectiveMccMnc)?.let { return it }

        // 3. Try MCC/MNC fallback
        getCarrierFromMccMnc(effectiveMccMnc)?.let { return it }

        // 4. Primary slot fallback to default TelephonyManager
        if (info.simSlotIndex == 0 && telephonyManager != null) {
            cleanBrandName(telephonyManager.simOperatorName, telephonyManager.simOperator)?.let { return it }
        }

        return if (!carrierName.isNullOrEmpty() && !isGenericCarrierName(carrierName)) {
            carrierName
        } else {
            "SIM ${info.simSlotIndex + 1}"
        }
    }

    private fun convertBengaliDigits(input: String): String {
        val bengali = charArrayOf('০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯')
        val english = charArrayOf('0', '1', '2', '3', '4', '5', '6', '7', '8', '9')
        var result = input
        for (i in bengali.indices) {
            result = result.replace(bengali[i], english[i])
        }
        return result
    }

    private fun getSmsManager(context: Context, simSlot: Int?): SmsManager? {
        if (simSlot != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            try {
                val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
                val activeList = subscriptionManager?.activeSubscriptionInfoList
                if (activeList != null && activeList.isNotEmpty()) {
                    val subInfo = activeList.firstOrNull { it.simSlotIndex == simSlot }
                        ?: activeList.firstOrNull { it.simSlotIndex == simSlot + 1 }
                        ?: if (activeList.size > simSlot) activeList[simSlot] else null

                    if (subInfo != null) {
                        val subId = subInfo.subscriptionId
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            val manager = context.getSystemService(SmsManager::class.java)
                            if (manager != null) {
                                return manager.createForSubscriptionId(subId)
                            }
                        }
                        @Suppress("DEPRECATION")
                        return SmsManager.getSmsManagerForSubscriptionId(subId)
                    }
                }

                // Fallback for Android 10+ using getSubscriptionIds
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && subscriptionManager != null) {
                    val subIds = subscriptionManager.getSubscriptionIds(simSlot)
                    if (subIds != null && subIds.isNotEmpty()) {
                        val subId = subIds[0]
                        val manager = context.getSystemService(SmsManager::class.java)
                        if (manager != null) {
                            return manager.createForSubscriptionId(subId)
                        }
                        @Suppress("DEPRECATION")
                        return SmsManager.getSmsManagerForSubscriptionId(subId)
                    }
                }
            } catch (e: Throwable) {
                // Fallback to default safely on any vendor quirk
            }
        }

        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                context.getSystemService(SmsManager::class.java) ?: @Suppress("DEPRECATION") SmsManager.getDefault()
            } else {
                @Suppress("DEPRECATION")
                SmsManager.getDefault()
            }
        } catch (e: Throwable) {
            @Suppress("DEPRECATION")
            try {
                SmsManager.getDefault()
            } catch (t: Throwable) {
                null
            }
        }
    }

    private fun getSimDeviceInfo(context: Context): Map<String, Any> {
        val telephonyManager = context.getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
        var maxSlots = 1
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                maxSlots = telephonyManager?.activeModemCount ?: 1
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                @Suppress("DEPRECATION")
                maxSlots = telephonyManager?.phoneCount ?: 1
            }
        } catch (e: Throwable) {
            maxSlots = 1
        }
        if (maxSlots < 1) maxSlots = 1

        val activeSlots = mutableListOf<Int>()
        val carriers = mutableMapOf<String, String>()
        var subscriptionListReadSuccess = false

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
            val subscriptionManager = context.getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
            if (subscriptionManager != null) {
                try {
                    val list = subscriptionManager.activeSubscriptionInfoList
                    if (list != null) {
                        subscriptionListReadSuccess = true
                        val minSlot = list.map { it.simSlotIndex }.filter { it >= 0 }.minOrNull() ?: 0
                        for (info in list) {
                            val rawSlot = info.simSlotIndex
                            if (rawSlot >= 0) {
                                val slot = if (minSlot > 0) rawSlot - minSlot else rawSlot
                                if (!activeSlots.contains(slot)) {
                                    activeSlots.add(slot)
                                }
                                val name = resolveCarrierName(telephonyManager, info)
                                carriers[slot.toString()] = name
                            }
                        }
                    }
                } catch (e: Throwable) {
                    // SecurityException or other vendor restriction
                }
            }
        }

        // If activeSubscriptionInfoList was blocked or returned empty:
        if (!subscriptionListReadSuccess || activeSlots.isEmpty()) {
            // Check TelephonyManager getSimState if available (Android 8.0+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && telephonyManager != null) {
                try {
                    for (slot in 0 until maxSlots) {
                        val state = telephonyManager.getSimState(slot)
                        if (state == TelephonyManager.SIM_STATE_READY) {
                            if (!activeSlots.contains(slot)) {
                                activeSlots.add(slot)
                            }
                        }
                    }
                } catch (_: Throwable) {}
            }

            // Fallback for activeSlots
            if (activeSlots.isEmpty()) {
                for (s in 0 until maxSlots) {
                    activeSlots.add(s)
                }
            } else if (!subscriptionListReadSuccess && maxSlots >= 2 && activeSlots.size < 2) {
                for (s in 0 until maxSlots) {
                    if (!activeSlots.contains(s)) {
                        activeSlots.add(s)
                    }
                }
            }

            // Fallback carrier extraction for primary slot
            if (telephonyManager != null) {
                try {
                    val defaultCarrier = telephonyManager.simOperatorName?.trim()?.takeIf { !isGenericCarrierName(it) }
                        ?: getCarrierFromMccMnc(telephonyManager.simOperator)
                    if (!defaultCarrier.isNullOrEmpty() && !carriers.containsKey("0")) {
                        carriers["0"] = defaultCarrier
                    }
                } catch (_: Throwable) {}
            }
        }

        activeSlots.sort()

        return mapOf(
            "maxSlots" to maxSlots,
            "activeSlots" to activeSlots,
            "carriers" to carriers
        )
    }
}

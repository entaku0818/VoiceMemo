package com.entaku.simpleRecord.transcription

import android.content.Context
import android.content.SharedPreferences

enum class AIPurpose { AUDIO, MINUTES }

interface AIConsentStore {
    fun allowed(purpose: AIPurpose): Boolean
    fun allow(purpose: AIPurpose)
    fun reset()
    fun require(purpose: AIPurpose) {
        check(allowed(purpose)) { "AI sharing permission is required. Please review consent in the app." }
    }
}

/** Fail closed before initialization. Versioned, separate permissions for each payload. */
object AISharingConsent : AIConsentStore {
    private var preferences: SharedPreferences? = null
    fun initialize(context: Context) {
        preferences = context.applicationContext.getSharedPreferences("ai_sharing", Context.MODE_PRIVATE)
    }
    private fun key(purpose: AIPurpose) = "${purpose.name.lowercase()}_consent_v2"
    override fun allowed(purpose: AIPurpose) = preferences?.getBoolean(key(purpose), false) == true
    override fun allow(purpose: AIPurpose) {
        preferences?.edit()?.putBoolean(key(purpose), true)?.apply()
    }
    override fun reset() {
        preferences?.edit()?.clear()?.apply()
    }
}

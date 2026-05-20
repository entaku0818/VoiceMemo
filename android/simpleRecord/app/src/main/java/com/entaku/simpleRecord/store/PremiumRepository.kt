package com.entaku.simpleRecord.store

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

class PremiumRepository internal constructor(context: Context) {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("premium_status", Context.MODE_PRIVATE)

    private val _isPremium = MutableStateFlow(prefs.getBoolean(KEY_IS_PREMIUM, false))
    val isPremium: StateFlow<Boolean> = _isPremium.asStateFlow()

    fun setPremium(value: Boolean) {
        prefs.edit { putBoolean(KEY_IS_PREMIUM, value) }
        _isPremium.value = value
    }

    companion object {
        private const val KEY_IS_PREMIUM = "is_premium"

        @Volatile
        private var instance: PremiumRepository? = null

        fun getInstance(context: Context): PremiumRepository =
            instance ?: synchronized(this) {
                instance ?: PremiumRepository(context.applicationContext).also { instance = it }
            }
    }
}

package com.entaku.simpleRecord.settings

import android.content.ComponentName
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import androidx.core.content.edit
import com.entaku.simpleRecord.R

enum class AppIcon(val aliasName: String, val iconRes: Int) {
    DEFAULT("com.entaku.simpleRecord.MainActivityDefault", R.mipmap.ic_launcher),
    BLUE("com.entaku.simpleRecord.MainActivityBlue", R.mipmap.ic_launcher_blue),
    PURPLE("com.entaku.simpleRecord.MainActivityPurple", R.mipmap.ic_launcher_purple)
}

class AppIconRepository(private val context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(
        "app_settings", Context.MODE_PRIVATE
    )

    fun getCurrentIcon(): AppIcon {
        val name = prefs.getString(KEY_SELECTED_ICON, AppIcon.DEFAULT.name)
        return AppIcon.entries.find { it.name == name } ?: AppIcon.DEFAULT
    }

    fun setIcon(icon: AppIcon) {
        val packageManager = context.packageManager
        AppIcon.entries.forEach { candidate ->
            val newState = if (candidate == icon) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED
            } else {
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED
            }
            packageManager.setComponentEnabledSetting(
                ComponentName(context.packageName, candidate.aliasName),
                newState,
                PackageManager.DONT_KILL_APP
            )
        }
        prefs.edit {
            putString(KEY_SELECTED_ICON, icon.name)
        }
    }

    companion object {
        private const val KEY_SELECTED_ICON = "selected_app_icon"
    }
}

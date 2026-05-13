// Top-level build file where you can add configuration options common to all sub-projects/modules.
plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.jetbrains.kotlin.android) apply false
    id("com.google.devtools.ksp") version "1.9.0-1.0.13" apply false
    alias(libs.plugins.roborazzi) apply false
    // Firebase: place google-services.json in app/ then uncomment the line below
    // id("com.google.gms.google-services") version "4.4.2" apply false
    // id("com.google.firebase.crashlytics") version "3.0.2" apply false
}
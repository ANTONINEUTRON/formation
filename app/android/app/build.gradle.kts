// AGP 9 marks the legacy `android { }` extension (BaseAppModuleExtension) as
// DeprecationLevel.ERROR in favour of ApplicationExtension. We cannot move to
// the new DSL yet: google-services 4.3.15 still reads `applicationVariants`,
// which the new extension does not expose. Suppress until that plugin is
// upgraded to an AGP 9-compatible release, then drop this and set
// android.newDsl=true in gradle.properties.
@file:Suppress("DEPRECATION", "DEPRECATION_ERROR")

import java.io.FileInputStream
import java.util.Properties

// Release signing. `android/key.properties` is gitignored and holds the
// keystore path and passwords; without it, release builds fall back to the
// debug key so `flutter run --release` still works on a fresh clone.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "ng.anto.formation"
    compileSdk = 37
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "ng.anto.formation"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion  // solana_mobile_client (MWA) requires API 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // An unsigned-with-debug-keys APK cannot be distributed, so this
            // is the real key whenever key.properties is present.
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
    }
}

flutter {
    source = "../.."
}

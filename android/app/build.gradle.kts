plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

android {
    namespace = "com.sardobabukhara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Application ID must match Play Console package name.
        applicationId = "com.sardobabukhara.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = 2
        versionName = "1.0.1"
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePasswordValue = keystoreProperties.getProperty("storePassword")
            val keyAliasValue = keystoreProperties.getProperty("keyAlias")
            val keyPasswordValue = keystoreProperties.getProperty("keyPassword")

            if (storeFilePath != null &&
                storePasswordValue != null &&
                keyAliasValue != null &&
                keyPasswordValue != null
            ) {
                storeFile = rootProject.file(storeFilePath)
                storePassword = storePasswordValue
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
            }
        }
    }

    buildTypes {
        release {
            // For Google Play upload, use a release keystore via android/key.properties.
            signingConfig = signingConfigs.getByName(
                if (keystorePropertiesFile.exists()) "release" else "debug"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.yandex.android:maps.mobile:4.5.1-lite")
}

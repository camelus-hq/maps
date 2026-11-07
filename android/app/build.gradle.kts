import org.gradle.authentication.http.BasicAuthentication

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The Mapbox Android SDK is hosted on Mapbox's Maven repository and needs a
// secret downloads token (Mapbox account → tokens → Downloads:Read). Never
// commit the token: set MAPBOX_DOWNLOADS_TOKEN in ~/.gradle/gradle.properties
// or android/gradle.properties (gitignored).
repositories {
    maven {
        url = uri("https://api.mapbox.com/downloads/v2/releases/maven")
        authentication { create<BasicAuthentication>("basic") }
        credentials {
            username = "mapbox"
            password = providers.gradleProperty("MAPBOX_DOWNLOADS_TOKEN").orNull ?: ""
        }
    }
}

android {
    namespace = "app.camelus.maps"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.camelus.maps"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        multiDexEnabled = true
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // FileProvider, used to hand the downloaded self-update APK to the system
    // package installer (see MainActivity.installApk).
    // 1.17.0 adds NotificationCompat's Android 16 Live Update APIs
    // (`setRequestPromotedOngoing`, `setShortCriticalText`) used for the
    // status-bar chip (see MainActivity.showNavigationNotification).
    implementation("androidx.core:core-ktx:1.17.0")
}

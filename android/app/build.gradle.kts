plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.healthcare"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by some libraries (e.g., flutter_local_notifications)
        // that use newer Java time APIs on older Android versions
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.healthcare"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
    minSdk = 26
    targetSdk = 35
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

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for Java 8+ APIs on older Android devices
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    // Firebase dependencies for ForegroundNotificationService
    implementation(platform("com.google.firebase:firebase-bom:33.5.1"))
    implementation("com.google.firebase:firebase-firestore-ktx")
    implementation("com.google.firebase:firebase-common-ktx")
    implementation("com.google.firebase:firebase-auth-ktx")
}

// Chaquopy configuration must be nested under android.defaultConfig in Kotlin DSL
android {
    defaultConfig {
        // Default config
    }
    // The default Python source directory is src/main/python, so no extra sourceSets
    // configuration is necessary. Uncomment below only if you need a custom path.
    // sourceSets {
    //     getByName("main") {
    //         python.srcDir("src/main/python")
    //     }
    // }
}

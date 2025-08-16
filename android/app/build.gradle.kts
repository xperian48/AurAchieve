plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.nicesapien.aura"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlin {
        // FIX: Replaced the deprecated `kotlinOptions` block with the modern `jvmToolchain`.
        jvmToolchain(11)
    }

    sourceSets {
        main {
            java {
                // Include the generated Flutter files.
                srcDir "$flutterRoot/packages/flutter_tools/templates/app/android/app/src/main/java"
            }
        }
    }

    defaultConfig {
        applicationId = "com.nicesapien.auraascend"
        // FIX: Changed minSdk to be an integer instead of a string.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

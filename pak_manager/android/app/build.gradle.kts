plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.github.truongthanhnam.pakmanager"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "io.github.truongthanhnam.pakmanager"
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AD-19: flavor `dev` cài song song với bản thật, không ghi đè vault thật.
    flavorDimensions += "env"
    productFlavors {
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appLabel"] = "PAK Manager"
        }
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            manifestPlaceholders["appLabel"] = "PAK Manager Dev"
        }
    }

    buildTypes {
        release {
            // Khóa ký thật chỉ nằm trong GitHub Secrets trên workflow của main/tag (AD-18).
            // PR build ký bằng debug key để `flutter build apk --release` chạy được.
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

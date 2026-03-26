plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // ★ namespace를 Town Helpers에 맞춰 변경했습니다.
    namespace = "com.townhelpers.keepers_note"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // ★ 카카오 개발자 센터 '패키지 명' 칸에도 똑같이 "com.townhelpers.keepers_note"를 넣으셔야 합니다!
        applicationId = "com.townhelpers.keepers_note"

        // 카카오 SDK는 보통 minSdk 21 이상을 권장합니다.
        // flutter.minSdkVersion이 21보다 낮다면 직접 21로 적어주셔도 좋습니다.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
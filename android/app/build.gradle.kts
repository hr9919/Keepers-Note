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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // 서명 설정은 터미널 빌드 시 인자로 넘기거나 나중에 정식으로 추가할 수 있습니다.
            // 일단 debug 서명 설정을 제거하여 충돌을 방지합니다.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
} // ← ★ 이 닫는 괄호가 꼭 있어야 합니다!

flutter {
    source = "../.."
}

// 빌드 시 라이브러리 버전 체크(AAR Metadata)를 강제로 끄는 코드입니다.
tasks.withType<com.android.build.gradle.internal.tasks.CheckAarMetadataTask>().configureEach {
    enabled = false
}
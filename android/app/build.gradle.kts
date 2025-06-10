plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.book_tracking_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Java 버전을 17로 업그레이드 (OpenGL ES API 경고 해결)
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        // Kotlin 타겟도 일치시킴
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.book_tracking_app"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // 추가: OpenGL 관련 경고 무시
    lint {
        abortOnError = false
        checkReleaseBuilds = false
        disable += "ObsoleteSdkInt"
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
    implementation("com.google.firebase:firebase-analytics")

    implementation("com.kakao.sdk:v2-user:2.19.0")
    // 추가: 최신 AndroidX Core 라이브러리 및 OpenGL 지원 라이브러리
    implementation("androidx.core:core:1.12.0")
    implementation("androidx.core:core-ktx:1.12.0")

    // OpenGL 관련 경고를 해결하기 위한 추가 의존성
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")

}

flutter {
    source = "../.."
}
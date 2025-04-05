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
    namespace = "com.example.startup"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.startup"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    lint {
        abortOnError = false
        checkReleaseBuilds = false
        disable += "ObsoleteSdkInt"
    }
} // **android 블록 닫는 중괄호 추가**

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.1"))
    implementation("com.google.firebase:firebase-analytics")

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

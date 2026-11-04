import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter integration_test may remove its test app after execution. Keep those
// installs separate from the normal development app and its saved progress.
val isolatedIntegration = providers.gradleProperty("dart-defines").orNull
    ?.split(',')?.any {
        String(Base64.getDecoder().decode(it), Charsets.UTF_8) == "AIRZERO_INTEGRATION=true"
    } ?: false
val integrationTarget = providers.gradleProperty("target").orNull
    ?.replace('\\', '/')?.contains("/integration_test/") ?: false
if (integrationTarget && !isolatedIntegration) {
    throw GradleException("Integration tests require --dart-define=AIRZERO_INTEGRATION=true to preserve app data")
}
// Public native key only; no server secret is accepted by this build.
val kakaoNativeKey = providers.gradleProperty("dart-defines").orNull
    ?.split(',')?.map { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
    ?.firstOrNull { it.startsWith("AIRZERO_KAKAO_NATIVE_KEY=") }?.substringAfter('=') ?: ""
if (kakaoNativeKey.isNotEmpty() && !Regex("^[a-f0-9]{32}$").matches(kakaoNativeKey)) {
    throw GradleException("Invalid public Kakao native key")
}

android {
    namespace = "com.example.raikeopeu2026"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.raikeopeu2026.dev"
        manifestPlaceholders["airzeroKakaoScheme"] = if (kakaoNativeKey.isEmpty()) "airzero-kakao-unconfigured" else "kakao$kakaoNativeKey"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("debug") {
            if (isolatedIntegration) { applicationIdSuffix = ".integration" }
        }
        release {
            // Release signing is intentionally unconfigured. Store work is manual.
            if (isolatedIntegration && gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }) {
                throw GradleException("Integration flag is debug-only")
            }
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

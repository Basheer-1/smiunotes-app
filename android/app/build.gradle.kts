plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.smiunotes.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Production candidate identity. Confirm availability in Play Console before publishing.
        applicationId = "com.smiunotes.app"
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

    // Release credentials must come from the operator environment / CI secrets.
    // Never ship a production build signed by the shared debug keystore.
    val releaseKeystore = System.getenv("SMIUNOTES_RELEASE_KEYSTORE")
    val releaseStorePassword = System.getenv("SMIUNOTES_RELEASE_STORE_PASSWORD")
    val releaseKeyAlias = System.getenv("SMIUNOTES_RELEASE_KEY_ALIAS")
    val releaseKeyPassword = System.getenv("SMIUNOTES_RELEASE_KEY_PASSWORD")
    val releaseCredentialsPresent = listOf(
        releaseKeystore, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
    ).all { !it.isNullOrBlank() }

    if (releaseCredentialsPresent) {
        signingConfigs.create("release") {
            storeFile = file(releaseKeystore!!)
            storePassword = releaseStorePassword!!
            keyAlias = releaseKeyAlias!!
            keyPassword = releaseKeyPassword!!
        }
    }

    buildTypes {
        release {
            // Without a dedicated keystore this build intentionally stays unsigned.
            // A release artifact must never silently inherit debug signing.
            if (releaseCredentialsPresent) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = null
            }
        }
    }
}

dependencies {
    // Firebase is used ONLY to deliver Android push notifications.
    // Authentication, accounts, and notification data remain in Supabase.
    implementation(platform("com.google.firebase:firebase-bom:35.2.0"))
    implementation("com.google.firebase:firebase-messaging")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

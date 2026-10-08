plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "dev.sumbee"
    compileSdk = 37

    defaultConfig {
        // Final before the Play release (VISION.md §5.3): an applicationId can't change once published.
        applicationId = "dev.sumbee"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "0.1"
    }

    buildFeatures {
        compose = true
    }

    // The Play upload key lives outside the repo; its path and passwords come from
    // ~/.gradle/gradle.properties (README "Release signing"). Google re-signs with the app signing
    // key it holds (Play App Signing).
    val uploadStore = providers.gradleProperty("SUMBEE_UPLOAD_STORE_FILE").orNull
    signingConfigs {
        if (uploadStore != null) {
            create("upload") {
                storeFile = file(uploadStore)
                storePassword = providers.gradleProperty("SUMBEE_UPLOAD_STORE_PASSWORD").get()
                keyAlias = providers.gradleProperty("SUMBEE_UPLOAD_KEY_ALIAS").get()
                keyPassword = providers.gradleProperty("SUMBEE_UPLOAD_KEY_PASSWORD").get()
            }
        }
    }

    buildTypes {
        release {
            // FR-7: small APK and fast start — R8 with resource shrinking.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            // The upload key when this machine has it; otherwise the debug key, which still installs
            // for family use but which Play rejects.
            signingConfig = signingConfigs.findByName("upload") ?: signingConfigs.getByName("debug")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)
    implementation(libs.activity.compose)
    implementation(libs.lifecycle.viewmodel.compose)
    implementation(libs.lifecycle.runtime.compose)
    implementation(libs.datastore.preferences)
    implementation(libs.core.splashscreen)

    testImplementation(libs.junit)
    testImplementation(libs.coroutines.test)
}

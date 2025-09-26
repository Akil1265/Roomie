plugins {
    // Requires running Gradle with JDK 17+ (set JAVA_HOME or org.gradle.java.home=... in gradle.properties)
    id("com.android.application")
    id("com.google.gms.google-services") // FlutterFire
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin") // Must stay last
}

android {
    namespace = "com.example.roomie"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.roomie"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Signing configs commented out for development
    // signingConfigs {
    //     create("release") {
    //         storeFile = file("release-keystore.jks")
    //         storePassword = "Akil_1265"
    //         keyAlias = "release"
    //         keyPassword = "Akil_1265"
    //     }
    // }

    buildTypes {
        debug {
            // Debug builds use default debug keystore
        }
        release {
            // signingConfig = signingConfigs.getByName("release")
            // Using default keystore for now
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.2.0"))
    implementation("com.google.firebase:firebase-auth")
}

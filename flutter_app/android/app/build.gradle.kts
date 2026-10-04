import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Imzolash kalitlari `android/key.properties` faylida bo'ladi.
// Bu fayl `.gitignore` da — hech qachon GitHub'ga yuklanmaydi.
//
// DIQQAT: `storeFile` yo'q bo'lsa (kalit hali yaratilmagan bo'lsa) release
// build `debug` kaliti bilan imzolanadi. Bu ilovani o'z telefoningizga o'rnatib
// sinash uchun yetarli, lekin Google Play'ga yuklash uchun TO'G'RI kalit
// kerak. Kalit yo'qotilsa — ilovani hech qachon yangilash mumkin bo'lmaydi,
// shuning uchun uni albatta zaxiraga oling.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.familycontrol.family_control_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.familycontrol.family_control_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                // Kalit yo'q — ilova shu yerda ogohlantiriladi, chunki bu
                // natija Google Play'ga chiqarib bo'lmaydi.
                logger.warn(
                    "android/key.properties topilmadi — release build DEBUG kaliti " +
                        "bilan imzolanadi. Play Store uchun kalit yarating."
                )
                signingConfigs.getByName("debug")
            }

            // R8 ni o'chiramiz: Flutter plug-inlari ba'zi runtime reflection
            // ishlatadi, siqishda "ClassNotFound" xatolari chiqishi mumkin.
            // Hajm kamayishidan ko'ra barqarorlik muhimroq.
            isMinifyEnabled = false
            isShrinkResources = false
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

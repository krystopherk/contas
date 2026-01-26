pluginManagement {
    val flutterSdkPath = java.util.Properties().apply {
        val propertiesFile = java.io.File(rootDir, "local.properties")
        if (propertiesFile.exists()) {
            load(propertiesFile.inputStream())
        }
    }.getProperty("flutter.sdk")

    val flutterSdk = flutterSdkPath ?: throw java.io.FileNotFoundException("Flutter SDK not found in local.properties")

    includeBuild("$flutterSdk/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("com.android.application") version "8.2.0" apply false // Use 8.2.0 para ser mais compatível
    id("org.jetbrains.kotlin.android") version "1.9.0" apply false // <--- O SEGREDO ESTÁ AQUI
}

include(":app")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        maven { 
            url = uri("https://storage.googleapis.com/download.flutter.io") 
        }
        maven { 
            url = uri("https://jitpack.io") 
        }
    }
}

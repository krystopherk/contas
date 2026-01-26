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
        // 1. REPOSITÓRIO DE PLUGINS (Onde estava dando erro)
        maven {
            url = uri("https://plugins.gradle.org/m2/")
            isAllowInsecureProtocol = true
        }
        // 2. GOOGLE
        maven {
            url = uri("https://maven.google.com")
            isAllowInsecureProtocol = true
        }
        // 3. MAVEN CENTRAL
        maven {
            url = uri("https://repo1.maven.org/maven2/")
            isAllowInsecureProtocol = true
        }
    }
}

plugins {
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
    id("com.android.application") version "8.2.0" apply false
    id("org.jetbrains.kotlin.android") version "1.9.24" apply false
}

include(":app")

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        // REPETIMOS A MESMA LÓGICA PARA AS DEPENDÊNCIAS
        maven {
            url = uri("https://maven.google.com")
            isAllowInsecureProtocol = true
        }
        maven {
            url = uri("https://repo1.maven.org/maven2/")
            isAllowInsecureProtocol = true
        }
        maven {
            url = uri("https://jitpack.io")
            isAllowInsecureProtocol = true
        }
    }
}

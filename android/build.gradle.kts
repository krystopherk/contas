// INICIO DO ARQUIVO

// 1. Configuração do Script de Build (FERRAMENTAS) - Faltava isso!
buildscript {
    repositories {
        google()
        mavenCentral()

        // Bypass para baixar os PLUGINS (Gradle, Kotlin, etc)
        maven {
            url = uri("https://plugins.gradle.org/m2/")
            isAllowInsecureProtocol = true
        }
    }
    dependencies {
        // Definição das ferramentas essenciais
        // Nota: O Flutter geralmente gerencia as versões, mas precisamos dos repositórios acima
        classpath("com.android.tools.build:gradle:8.0.0") // Versão base segura
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.8.20") // Versão base segura
    }
}

// 2. Configuração dos Subprojetos (BIBLIOTECAS DO APP)
allprojects {
    repositories {
        google()
        mavenCentral()

        // Bypass para baixar as DEPENDÊNCIAS do app
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

// 3. Configuração da pasta de Build (Padrão do Flutter Novo)
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
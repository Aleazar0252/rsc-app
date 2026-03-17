// android/build.gradle.kts

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // This is the critical line you were missing:
        classpath("com.google.gms:google-services:4.4.1")
        
        // Add the Kotlin Gradle plugin (required for Kotlin DSL)
        classpath("com.android.tools.build:gradle:8.2.1") 
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
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
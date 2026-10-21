pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.4.0" apply false
}

rootProject.name = "material-3-frosted-verify"

// The expressive module compiles the examples against material3 1.5.0-beta01.
// The stable module compiles the stable-only example against material3 1.4.0.
include(":expressive")
include(":stable")

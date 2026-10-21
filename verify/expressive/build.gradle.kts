import org.gradle.api.tasks.Sync
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Stage exactly the files this module owns. Source-set excludes on AGP-provided directories
// are unreliable, and a silently-excluded file would make this harness pass while compiling
// nothing — the failure mode we are trying to catch.
val examples by tasks.registering(Sync::class) {
    // `*.kt` matches the five top-level examples and deliberately not `stable/`,
    // which is a subdirectory and belongs to the :stable module.
    from("../../skills/material-3-frosted/assets/examples") {
        include("*.kt")
    }
    into(layout.buildDirectory.dir("generated/examples"))
}

android {
    namespace = "dev.material3frosted.verify.expressive"
    compileSdk = 37

    defaultConfig {
        // Haze declares minSdk 23. Real blur needs 31 and Glass refraction needs 33 at
        // runtime, but the code must still compile on this floor.
        minSdk = 23
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
    }

    sourceSets["main"].kotlin.srcDir(examples)
}

// AGP cannot infer the dependency on the staging task, so wire it explicitly for every
// Kotlin compilation (debug, release, and any test variants).
tasks.matching { it.name.startsWith("compile") && it.name.endsWith("Kotlin") }
    .configureEach { dependsOn(examples) }

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_17
    }
}

dependencies {
    val composeBom = platform("androidx.compose:compose-bom:2026.09.00")
    implementation(composeBom)

    implementation("androidx.compose.material3:material3:1.5.0-beta01")
    implementation("androidx.compose.material3.adaptive:adaptive:1.3.0")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.runtime:runtime")

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.1")

    // Frosted layer — all artifacts on one version, as the skill instructs.
    implementation("dev.chrisbanes.haze:haze:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur-materials:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur-material3:2.0.1")
    implementation("dev.chrisbanes.haze:haze-glass:2.0.1")
    implementation("dev.chrisbanes.haze:haze-glass-material3:2.0.1")
}

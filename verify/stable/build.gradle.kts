import org.gradle.api.tasks.Sync
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("org.jetbrains.kotlin.plugin.compose")
}

// Proves the stable-only path really compiles: material3 1.4.0, no Expressive API, and the
// stable theme standing in for FrostedTheme.kt.
val examples by tasks.registering(Sync::class) {
    from("../../skills/material-3-frosted/assets/examples") {
        include("*.kt")
        exclude("FrostedTheme.kt") // the expressive theme; replaced by the stable one below
    }
    from("../../skills/material-3-frosted/assets/examples/stable") {
        include("*.kt")
    }
    into(layout.buildDirectory.dir("generated/examples"))
}

android {
    namespace = "dev.material3frosted.verify.stable"
    compileSdk = 37

    defaultConfig {
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

    // Deliberately NOT 1.5.0-beta01.
    implementation("androidx.compose.material3:material3:1.4.0")
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.runtime:runtime")

    implementation("androidx.activity:activity-compose:1.13.0")
    implementation("androidx.core:core-ktx:1.19.1")

    implementation("dev.chrisbanes.haze:haze:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur:2.0.1")
    implementation("dev.chrisbanes.haze:haze-blur-materials:2.0.1")
    implementation("dev.chrisbanes.haze:haze-glass:2.0.1")
    implementation("dev.chrisbanes.haze:haze-glass-material3:2.0.1")
}

# verify/ — the examples compile harness

The Kotlin in `../skills/material-3-frosted/assets/examples/` is shipped code: people copy it
into their apps. Parsing it is not enough. A function that was removed, renamed, or never
existed on the release line parses perfectly and fails on the reader's first build.

This project compiles every example against the real dependencies.

```bash
./gradlew :expressive:compileDebugKotlin   # material3 1.5.0-beta01 + Haze 2.0.1, minSdk 23
./gradlew :stable:compileDebugKotlin       # material3 1.4.0, the stable path
```

## How it stays honest

Each module has a `Sync` task that copies the examples it owns into `build/generated/examples`
and adds that directory as the Kotlin source root. There is exactly one copy of every example —
the one the skill ships — so the harness cannot drift from the docs.

`:expressive` takes `*.kt` (the five top-level files). `:stable` takes `FrostedThemeStable.kt`
plus the four files that do not depend on the expressive-only APIs. The `stable/` subdirectory
belongs to `:stable` and is never pulled into `:expressive`.

## The failure mode to watch

An earlier version of this harness pointed at a relative path that did not exist. Gradle was
happy, the exit status was 0, and it compiled **zero files**. An exit code is not evidence.

So CI counts classes:

```bash
find expressive/build -name '*.class' -not -name 'R.class' | wc -l   # ~25, not 0
```

If you change the build files and that number collapses, the harness has gone silent.

## What this proves, and what it does not

It proves every symbol, signature and visibility the examples use exists in the pinned
artifacts. It does **not** run the code, assemble an APK, or look at a pixel — the examples have
no `Activity` and no resources. Visual correctness is a design judgment, exercised by
`references/audit-rubric.md`, not by this build.

## Requirements

JDK 17+ and an Android SDK with the platform AGP asks for (`compileSdk 37`). AGP downloads it
once the licences are accepted. `local.properties` is gitignored — never commit an `sdk.dir`.

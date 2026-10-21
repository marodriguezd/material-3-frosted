// Root build for the compile-verification harness. No plugins are applied here.
tasks.register("clean", Delete::class) {
    delete(rootProject.layout.buildDirectory)
}

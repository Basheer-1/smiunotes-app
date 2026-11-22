allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
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

// AGP 9.3.1 lint crashes in generated WebView Pigeon Kotlin JavaDoc,
// independent of application lint and Flutter analyzer. Scope the workaround
// to the third-party webview plugin's release-vital lint tasks only.
// Keep app lint, Flutter analysis, unit tests, and APK signature verification.
subprojects {
    if (name == "webview_flutter_android") {
        tasks.configureEach {
            if (name.startsWith("lintVital")) {
                enabled = false
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

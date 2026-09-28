allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// Some plugins (e.g. objectbox_flutter_libs sets compileSdkVersion 31) compile
// against an SDK older than their AndroidX dependencies require, which fails
// checkReleaseAarMetadata. Raise every Android library module to the app's SDK.
val appCompileSdk = 36
subprojects {
    val raiseCompileSdk: Project.() -> Unit = {
        extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)?.let { android ->
            if ((android.compileSdk ?: 0) < appCompileSdk) {
                android.compileSdk = appCompileSdk
            }
        }
    }
    if (state.executed) raiseCompileSdk() else afterEvaluate { raiseCompileSdk() }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

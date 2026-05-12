import org.gradle.api.JavaVersion
import com.android.build.gradle.LibraryExtension
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension>("android") {
            compileOptions.sourceCompatibility = JavaVersion.VERSION_21
            compileOptions.targetCompatibility = JavaVersion.VERSION_21

            if (namespace == null) {
                namespace = when (project.name) {
                    "on_audio_query_android" -> "com.lucasjosino.on_audio_query"
                    else -> project.group.toString().takeIf { it.isNotBlank() && it != "unspecified" }
                        ?: "com.vibematch.${project.name.replace("-", "_")}"
                }
            }
        }
    }
}


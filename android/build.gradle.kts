allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Force every Android library plugin module onto compileSdk 36 (file_picker AAR metadata).
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        try {
            val m = android.javaClass.methods.firstOrNull { method ->
                method.name == "setCompileSdk" &&
                    method.parameterCount == 1 &&
                    (method.parameterTypes[0] == Int::class.javaPrimitiveType ||
                        method.parameterTypes[0] == Integer::class.java)
            }
            m?.invoke(android, 36)
        } catch (_: Exception) {
            // ignore
        }
        try {
            val m = android.javaClass.methods.firstOrNull { method ->
                method.name == "setCompileSdkVersion" && method.parameterCount == 1
            }
            m?.invoke(android, 36)
        } catch (_: Exception) {
            // ignore
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

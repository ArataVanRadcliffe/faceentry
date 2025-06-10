// File: android/build.gradle.kts

// Konfigurasi untuk semua repositori di semua proyek
allprojects {
    repositories {
        google()        // Repositori Google Maven
        mavenCentral()  // Repositori Maven Central
    }
}

// Deklarasi plugin-plugin yang digunakan di proyek
// 'id' adalah ID plugin, 'version' adalah versinya.
// 'apply false' berarti plugin ini dideklarasikan di sini tapi tidak langsung diterapkan.
// Ini akan diterapkan di file build.gradle.kts tingkat aplikasi.


// Kustomisasi direktori build (opsional, jika Anda memang ingin memindahkan direktori build)
// Ini mengubah direktori build dari default menjadi di luar direktori 'android'
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Kustomisasi direktori build untuk subproyek
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Memastikan subproyek dievaluasi setelah proyek ':app'
subprojects {
    project.evaluationDependsOn(":app")
}

// Task 'clean' kustom untuk menghapus direktori build
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
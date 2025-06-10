// android/app/build.gradle.kts

// Terapkan plugin-plugin yang telah dideklarasikan di project-level build.gradle.kts.
// Di sini, kita hanya menyebutkan ID plugin, bukan versinya, karena versi sudah diatur di project-level.
plugins {
    id("com.android.application")           // Menerapkan plugin Android Gradle untuk aplikasi.
    id("kotlin-android")                    // Menerapkan plugin Kotlin Android.
    id("dev.flutter.flutter-gradle-plugin") // Menerapkan plugin Flutter Gradle.
    id("com.google.gms.google-services")    // Menerapkan plugin Google Services untuk Firebase.
}

// Konfigurasi dependensi aplikasi.
dependencies {
    // Import the Firebase BoM (Bill of Materials).
    // Ini mengelola versi semua library Firebase agar kompatibel satu sama lain.
    // Selalu gunakan versi BoM terbaru yang stabil. Periksa rilis terbaru di:
    // https://firebase.google.com/docs/android/setup#available-libraries
    implementation(platform("com.google.firebase:firebase-bom:33.14.0")) // Gunakan versi 33.14.0 atau yang terbaru.

    // Tambahkan dependensi untuk produk Firebase yang ingin Anda gunakan.
    // Ketika menggunakan BoM, Anda TIDAK PERLU MENENTUKAN VERSI di dependensi Firebase individual.
    implementation("com.google.firebase:firebase-analytics") // Contoh: Untuk Google Analytics.
    implementation("com.google.firebase:firebase-auth")      // Contoh: Untuk autentikasi Firebase.
    // TODO: Tambahkan dependensi Firebase lainnya yang Anda butuhkan di sini.
    // Contoh:
    // implementation("com.google.firebase:firebase-firestore")
    // implementation("com.google.firebase:firebase-storage")
    // implementation("com.google.firebase:firebase-messaging")
}

// Konfigurasi spesifik untuk modul Android Anda.
android {
    namespace = "com.stecu.faceentry.faceentry" // Namespace unik untuk aplikasi Anda.
    compileSdk = flutter.compileSdkVersion      // Menggunakan SDK versi yang ditentukan oleh Flutter.
    ndkVersion = "27.0.12077973"               // Versi NDK yang digunakan.

    // Konfigurasi opsi kompilasi Java.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11 // Versi Java sumber.
        targetCompatibility = JavaVersion.VERSION_11 // Versi Java target.
    }

    // Konfigurasi opsi Kotlin.
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString() // Target JVM untuk kompilasi Kotlin.
    }

    // Konfigurasi default untuk aplikasi Anda.
    defaultConfig {
        // TODO: Tentukan Application ID unik Anda sendiri (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.stecu.faceentry.faceentry" // ID aplikasi unik.
        minSdk = 23                                 // Versi SDK Android minimum yang didukung.
        targetSdk = flutter.targetSdkVersion        // Versi SDK Android target yang didukung oleh Flutter.
        versionCode = flutter.versionCode           // Kode versi aplikasi (integer).
        versionName = flutter.versionName           // Nama versi aplikasi (string).
    }

    // Konfigurasi build types (misalnya, release dan debug).
    buildTypes {
        release {
            // TODO: Tambahkan konfigurasi signing Anda sendiri untuk build rilis.
            // Saat ini, menggunakan debug keys untuk signing agar `flutter run --release` berfungsi.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// Konfigurasi spesifik Flutter.
flutter {
    source = "../.." // Menentukan lokasi sumber Flutter relatif terhadap file ini.
}
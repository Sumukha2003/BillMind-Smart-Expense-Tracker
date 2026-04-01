buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // ✅ Firebase plugin
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
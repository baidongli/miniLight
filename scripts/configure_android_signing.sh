#!/usr/bin/env bash
# Configures Android release signing for Play upload. Reads the keystore
# from CI secrets (env). If no keystore is provided the build still works
# (debug-signed), so local/PR builds are unaffected.
#
# Required env for a Play-ready build:
#   ANDROID_KEYSTORE_BASE64   base64 of the upload keystore (.jks)
#   ANDROID_KEYSTORE_PASSWORD store password
#   ANDROID_KEY_ALIAS         key alias
#   ANDROID_KEY_PASSWORD      key password
set -euo pipefail

APP=android/app
GRADLE="$APP/build.gradle.kts"

HAVE_KEYSTORE=0
if [[ -n "${ANDROID_KEYSTORE_BASE64:-}" ]]; then
  echo "$ANDROID_KEYSTORE_BASE64" | base64 -d > "$APP/upload-keystore.jks"
  cat > android/key.properties <<EOF
storeFile=upload-keystore.jks
storePassword=${ANDROID_KEYSTORE_PASSWORD}
keyAlias=${ANDROID_KEY_ALIAS}
keyPassword=${ANDROID_KEY_PASSWORD}
EOF
  HAVE_KEYSTORE=1
  echo "Android: release keystore configured."
else
  echo "Android: no keystore secret; building debug-signed."
fi

if [[ -f "$APP/build.gradle" && ! -f "$GRADLE" ]]; then
  # Older Flutter generated a Groovy module build file.
  cat > "$APP/build.gradle" <<'GROOVY'
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
}

def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.withInputStream { keystoreProperties.load(it) }
}

android {
    namespace "com.minilight.minilight"
    compileSdk flutter.compileSdkVersion
    ndkVersion flutter.ndkVersion

    compileOptions {
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = "17" }

    defaultConfig {
        applicationId "com.minilight.minilight"
        minSdkVersion Math.max(flutter.minSdkVersion, 23)
        targetSdkVersion flutter.targetSdkVersion
        versionCode flutter.versionCode
        versionName flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            release {
                keyAlias keystoreProperties["keyAlias"]
                keyPassword keystoreProperties["keyPassword"]
                storeFile file(keystoreProperties["storeFile"])
                storePassword keystoreProperties["storePassword"]
            }
        }
    }

    buildTypes {
        release {
            signingConfig keystorePropertiesFile.exists() ?
                signingConfigs.release : signingConfigs.debug
            minifyEnabled false
        }
    }
}

flutter { source "../.." }

dependencies {}
GROOVY
  echo "Android: Groovy build.gradle written (keystore=$HAVE_KEYSTORE)."
  exit 0
fi

# Kotlin DSL project: write build.gradle.kts and drop any stale Groovy file.
rm -f "$APP/build.gradle"
cat > "$GRADLE" <<'KTS'
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.minilight.minilight"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.minilight.minilight"
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
        }
    }
}

flutter {
    source = "../.."
}
KTS

echo "Android: build.gradle.kts written (keystore=$HAVE_KEYSTORE)."

#!/usr/bin/env bash
# Injects the committed Android real-metering plugin into the CI-generated
# android/ project and wires permissions + plugin registration.
set -euo pipefail

PKG_DIR=android/app/src/main/kotlin/com/minilight/minilight
mkdir -p "$PKG_DIR"

# Copy the plugin, fixing its package to match the generated app id.
sed 's/^package .*/package com.minilight.minilight/' \
  native/android/CameraMeterPlugin.kt > "$PKG_DIR/CameraMeterPlugin.kt"

MANIFEST=android/app/src/main/AndroidManifest.xml
add_perm() {
  grep -q "$1" "$MANIFEST" || \
    sed -i "s#<application#<uses-permission android:name=\"$1\" />\n    <application#" "$MANIFEST"
}
add_perm android.permission.CAMERA
add_perm android.permission.ACCESS_FINE_LOCATION

# Register the (non-pub) plugin in MainActivity.
MAIN=$(find android/app/src/main/kotlin -name MainActivity.kt | head -1)
cat > "$MAIN" <<'KOT'
package com.minilight.minilight

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.plugins.add(CameraMeterPlugin())
    }
}
KOT

echo "Android native plugin injected."

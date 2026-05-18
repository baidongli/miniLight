#!/usr/bin/env bash
# Injects the committed iOS real-metering plugin into the CI-generated ios/
# project. The plugin source is folded into AppDelegate.swift so it compiles
# with the Runner target without editing the Xcode project file.
set -euo pipefail

APPDELEGATE=ios/Runner/AppDelegate.swift
{
  echo "import AVFoundation"
  echo "import Flutter"
  echo "import UIKit"
  echo ""
  echo "@main"
  echo "@objc class AppDelegate: FlutterAppDelegate {"
  echo "  override func application("
  echo "    _ application: UIApplication,"
  echo "    didFinishLaunchingWithOptions launchOptions:"
  echo "      [UIApplication.LaunchOptionsKey: Any]?"
  echo "  ) -> Bool {"
  echo "    GeneratedPluginRegistrant.register(with: self)"
  echo "    CameraMeterPlugin.register("
  echo "      with: self.registrar(forPlugin: \"CameraMeterPlugin\")!)"
  echo "    return super.application("
  echo "      application, didFinishLaunchingWithOptions: launchOptions)"
  echo "  }"
  echo "}"
  echo ""
  # Strip the plugin's own import lines (already imported above) and append.
  grep -v '^import ' native/ios/CameraMeterPlugin.swift
} > "$APPDELEGATE"

PLIST=ios/Runner/Info.plist
/usr/libexec/PlistBuddy -c \
  "Add :NSCameraUsageDescription string 'miniLight uses the camera to meter light.'" \
  "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c \
  "Add :NSLocationWhenInUseUsageDescription string 'miniLight tags shots with your location.'" \
  "$PLIST" 2>/dev/null || true

# geolocator / share_plus need a modern deployment target.
sed -i '' "s/# platform :ios, '12.0'/platform :ios, '13.0'/" ios/Podfile || true
grep -q "platform :ios" ios/Podfile || \
  sed -i '' "1i\\
platform :ios, '13.0'
" ios/Podfile || true

echo "iOS native plugin injected."

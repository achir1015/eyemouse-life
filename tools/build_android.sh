#!/usr/bin/env bash
# 匯出 Android APK（arm64，已簽章）→ ../build/release/EyeMouseLife-Android.apk
# 金鑰在專案外 ../keystore/eyemouselife.jks（不進 git）
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$(cd .. && pwd)"
GODOT="/e/從零建置 Godot 賽車遊戲/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROOT/keystore/eyemouselife.jks"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=eyemouselife
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=android
mkdir -p "$ROOT/build/release"
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Android" "$ROOT/build/EyeMouseLife-Android.apk" 2>&1 | grep -E "ERROR|WARN" || true
cp "$ROOT/build/EyeMouseLife-Android.apk" "$ROOT/build/release/EyeMouseLife-Android.apk"
ls -la "$ROOT/build/release/EyeMouseLife-Android.apk"

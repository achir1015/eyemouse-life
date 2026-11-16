#!/bin/bash
# 在 Mac 上匯出 macOS 版（Intel＋Apple 晶片通用），ad-hoc 簽章後包成 DMG。可直接用 SSH 執行。
# 產出：~/Developer/eyemouse-life-build/EyeMouseLife-macOS.dmg
set -e
PROJ=~/Developer/eyemouse-life
OUT=~/Developer/eyemouse-life-build/macos
GODOT=~/Developer/godot/Godot.app/Contents/MacOS/Godot
NAME="眼動鼠生活日常工具"

rm -rf "$OUT" && mkdir -p "$OUT"
"$GODOT" --headless --path "$PROJ" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$PROJ" --export-release "macOS" "$OUT/EyeMouseLife.app" 2>&1 | grep -E "ERROR|DONE" || true
cd "$OUT"
mv EyeMouseLife.app "$NAME.app"
xattr -cr "$NAME.app"
codesign --force --deep -s - "$NAME.app"
codesign --verify --deep "$NAME.app"
mkdir dmg && cp -R "$NAME.app" dmg/ && ln -s /Applications dmg/Applications
hdiutil create -volname "$NAME" -srcfolder dmg -ov -format UDZO -size 600m ../EyeMouseLife-macOS.dmg >/dev/null
rm -rf dmg
ls -l ../EyeMouseLife-macOS.dmg

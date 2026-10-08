#!/bin/bash
# ちんすこうメーカー APK ビルド（Gradle なし: aapt2 -> javac -> d8 -> zipalign -> apksigner）
set -euo pipefail

APP="$(cd "$(dirname "$0")" && pwd)"
SDK="$HOME/Android/Sdk"
BT="$SDK/build-tools/35.0.0"
PLATFORM="$SDK/platforms/android-35/android.jar"
JDK="$(ls -d "$HOME"/android-tools/jdk-17* | head -1)"
OUT="$APP/build"

# バージョンは AndroidManifest.xml を唯一の出典にする（build.sh 側で二重管理しない）
VERSION="$(grep -oE 'android:versionName="[^"]+"' "$APP/AndroidManifest.xml" | head -1 | sed -E 's/.*="([^"]+)"/\1/')"
VCODE="$(grep -oE 'android:versionCode="[^"]+"' "$APP/AndroidManifest.xml" | head -1 | sed -E 's/.*="([^"]+)"/\1/')"
APKNAME="ChinsukoMaker-${VERSION}.apk"
echo "version: ${VERSION} (code ${VCODE}) -> ${APKNAME}"
# スプラッシュに書いた版が Manifest とずれていないか（二重管理の検出）
grep -q "<div class=\"sp-ver\">v${VERSION}</div>" "$APP/../web/index.html" \
  || echo "WARN: web/index.html のスプラッシュ版（.sp-ver）が v${VERSION} と不一致"

export JAVA_HOME="$JDK"
export PATH="$JDK/bin:$PATH"

mkdir -p "$OUT/classes" "$OUT/gen" "$OUT/dex" "$APP/assets"

echo "[0/6] assets (HTML5本体を同梱)"
cp -f "$APP/../web/index.html" "$APP/assets/index.html"

echo "[0b/6] GitHub Pages 用（ブラウザでそのまま遊べる版）"
mkdir -p "$APP/../docs/play"
cp -f "$APP/../web/index.html" "$APP/../docs/play/index.html"

echo "[1/6] aapt2 compile"
"$BT/aapt2" compile --dir "$APP/res" -o "$OUT/res.zip"

echo "[2/6] aapt2 link"
"$BT/aapt2" link \
  -o "$OUT/base.apk" \
  -I "$PLATFORM" \
  --manifest "$APP/AndroidManifest.xml" \
  -R "$OUT/res.zip" \
  -A "$APP/assets" \
  --java "$OUT/gen" \
  --min-sdk-version 26 \
  --target-sdk-version 34 \
  --version-code "$VCODE" \
  --version-name "$VERSION" \
  --auto-add-overlay

echo "[3/6] javac"
"$JDK/bin/javac" -nowarn -source 17 -target 17 -Xlint:-options \
  -classpath "$PLATFORM" \
  -d "$OUT/classes" $(find "$APP/src" "$OUT/gen" -name '*.java')

echo "[4/6] d8 (dex)"
"$BT/d8" --release --lib "$PLATFORM" --min-api 26 \
  --output "$OUT/dex" $(find "$OUT/classes" -name '*.class')

echo "[5/6] package + align"
python3 - "$OUT" <<'PY'
import os, shutil, sys, zipfile
out = sys.argv[1]
dst = os.path.join(out, "unaligned.apk")
shutil.copy(os.path.join(out, "base.apk"), dst)
with zipfile.ZipFile(dst, "a", zipfile.ZIP_DEFLATED) as z:
    z.write(os.path.join(out, "dex", "classes.dex"), "classes.dex")
print("classes.dex embedded")
PY
"$BT/zipalign" -f -p 4 "$OUT/unaligned.apk" "$OUT/aligned.apk"

echo "[6/6] sign"
KS="$HOME/.android/debug-chinsuko.keystore"
if [ ! -f "$KS" ]; then
  mkdir -p "$HOME/.android"
  "$JDK/bin/keytool" -genkeypair -keystore "$KS" -alias androiddebugkey \
    -storepass android -keypass android -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Chinsuko Maker,O=Local,C=JP" >/dev/null 2>&1
fi
"$BT/apksigner" sign --ks "$KS" --ks-pass pass:android --key-pass pass:android \
  --v1-signing-enabled true --v2-signing-enabled true \
  --out "$OUT/$APKNAME" "$OUT/aligned.apk"
"$BT/apksigner" verify --print-certs "$OUT/$APKNAME" | head -3
echo
ls -la "$OUT/$APKNAME"
"$BT/aapt2" dump badging "$OUT/$APKNAME" | head -6

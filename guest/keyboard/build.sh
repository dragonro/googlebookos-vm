#!/bin/bash
# Build and sign the Android keyboard-layout provider APK.
. "$(cd "$(dirname "$0")/../.." && pwd)/lib.sh"
find_android
[ -n "$D8" ] && [ -n "$ANDROID_JAR" ] && [ -n "$JAVA_HOME" ] \
  || die "Android SDK build-tools/platform and a JDK are required. Run ./prereqs.sh first."
need zip "macOS command-line tools"

OUT="${GOOGLEBOOK_GUEST_DIR:-$WORK/guest}"
BUILD="$WORK/build/googlebook-keyboard-layouts"
RES="$ROOT/guest/keyboard/res"
APK="$OUT/GooglebookKeyboardLayouts.apk"
BUILD_TOOLS="$(dirname "$D8")"
for tool in "$BUILD_TOOLS/aapt2" "$BUILD_TOOLS/zipalign" "$BUILD_TOOLS/apksigner"; do
  [ -x "$tool" ] || die "Android build tool is missing: $tool"
done

rm -rf "$BUILD"
mkdir -p "$OUT" "$BUILD/classes" "$BUILD/dex" "$BUILD/generated"
"$BUILD_TOOLS/aapt2" compile --dir "$RES" -o "$BUILD/resources.zip"
"$BUILD_TOOLS/aapt2" link -I "$ANDROID_JAR" --manifest "$ROOT/guest/keyboard/AndroidManifest.xml" \
  --java "$BUILD/generated" --min-sdk-version 29 --target-sdk-version 35 \
  --version-code 1 --version-name 1.0 -o "$BUILD/resources.apk" "$BUILD/resources.zip"
"$JAVA_HOME/bin/javac" -source 11 -target 11 -Xlint:-options -cp "$ANDROID_JAR" \
  -d "$BUILD/classes" "$ROOT/guest/keyboard/src/com/googlebook/vm/keyboardlayouts/KeyboardLayoutProvider.java"
"$D8" --min-api 29 --lib "$ANDROID_JAR" --output "$BUILD/dex" \
  "$BUILD/classes"/com/googlebook/vm/keyboardlayouts/*.class
cp "$BUILD/resources.apk" "$BUILD/unsigned.apk"
(cd "$BUILD/dex" && zip -q -0 "$BUILD/unsigned.apk" classes.dex)

# Keep one local signing identity so image updates remain install-compatible. It is a
# non-privileged vendor app, and the private key stays in the ignored work directory.
KEYSTORE="$WORK/build/googlebook-keyboard.keystore"
if [ ! -f "$KEYSTORE" ]; then
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$KEYSTORE" -storepass googlebook-local \
    -keypass googlebook-local -alias googlebook-keyboard \
    -dname "CN=Googlebook VM Keyboard Layouts" -keyalg RSA -keysize 2048 \
    -validity 10000 -noprompt >/dev/null 2>&1
fi
chmod 600 "$KEYSTORE"
"$BUILD_TOOLS/zipalign" -f -p 4 "$BUILD/unsigned.apk" "$BUILD/aligned.apk"
"$BUILD_TOOLS/apksigner" sign --ks "$KEYSTORE" --ks-key-alias googlebook-keyboard \
  --ks-pass pass:googlebook-local --key-pass pass:googlebook-local --out "$APK" "$BUILD/aligned.apk"
"$BUILD_TOOLS/apksigner" verify --verbose "$APK"
say "Keyboard layout APK ready: $APK"

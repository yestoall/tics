#!/usr/bin/env bash
# Compila Tics y monta Tics.app en build/: ejecutable + Info.plist + packs, y la firma.
# Uso: scripts/build-app.sh [debug|release|dist]
# «dist» es la de repartir: release para Apple Silicon e Intel, firmada con Developer ID y con sello de
# tiempo, que es lo que pide la notarización (scripts/release.sh)
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/Tics.app"
BUILD_FLAGS=(-c "$CONFIG")
TIMESTAMP="--timestamp=none"
if [ "$CONFIG" = "dist" ]; then
  BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
  TIMESTAMP="--timestamp"
  IDENTITY="Developer ID Application"
  if ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "No está el certificado «${IDENTITY}»: sin él no se puede repartir"
    exit 1
  fi
else
  # Firmar siempre con el mismo certificado hace que macOS recuerde el permiso entre compilaciones.
  # Sin ese certificado, firma ad hoc: funciona, pero macOS vuelve a pedir el permiso en cada compilación
  IDENTITY="${SIGN_IDENTITY:-Apple Development}"
  if [ "$IDENTITY" != "-" ] && ! security find-identity -v -p codesigning | grep -q "$IDENTITY"; then
    echo "No está el certificado «${IDENTITY}»: firmo ad hoc"
    IDENTITY="-"
  fi
fi

cd "$ROOT"
swift build "${BUILD_FLAGS[@]}"
BIN="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/Tics"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Tics"
cp Info.plist "$APP/Contents/Info.plist"
cp -R Resources/SoundPacks "$APP/Contents/Resources/SoundPacks"
# El icono lo genera scripts/icon.swift
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Los textos están escritos en español en el código y el catálogo trae el inglés y el español
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
# Y el del Info.plist: el texto del permiso de Bluetooth
xcrun xcstringstool compile Resources/InfoPlist.xcstrings --output-directory "$APP/Contents/Resources"

codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$APP"
echo "→ $APP"

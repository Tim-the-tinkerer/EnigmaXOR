#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

LAUNCH=true
for arg in "$@"; do
    case "${arg}" in
        --no-launch) LAUNCH=false ;;
    esac
done

APP="EnigmaXOR.app"
BUNDLE_ID="com.tim.enigmaxor"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' AppInfo.plist 2>/dev/null || true)"
VERSION="${VERSION:-1.0.1}"

if [[ ! -f Assets/AppIcon.icns ]]; then
    echo "Generating app icon..."
    swift Scripts/GenerateAppIcon.swift
    if command -v sips >/dev/null && command -v iconutil >/dev/null && [[ -f Assets/AppIcon-1024.png ]]; then
        ICONSET="Assets/AppIcon.iconset"
        rm -rf "${ICONSET}"
        mkdir -p "${ICONSET}"
        for size in 16 32 128 256 512; do
            sips -z $size $size Assets/AppIcon-1024.png --out "${ICONSET}/icon_${size}x${size}.png" >/dev/null
            double=$((size * 2))
            sips -z $double $double Assets/AppIcon-1024.png --out "${ICONSET}/icon_${size}x${size}@2x.png" >/dev/null
        done
        iconutil -c icns "${ICONSET}" -o Assets/AppIcon.icns
    fi
fi

echo "Building Enigma XOR ${VERSION} (release)..."
swift build -c release --product EnigmaXOR

BIN=".build/release/EnigmaXOR"
if [[ ! -x "${BIN}" ]]; then
    echo "error: expected binary not found at ${BIN}" >&2
    exit 1
fi

echo "Running self-test..."
"${BIN}" --self-test

echo "Assembling ${APP}..."
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS"
mkdir -p "${APP}/Contents/Resources"
cp "${BIN}" "${APP}/Contents/MacOS/EnigmaXOR"
chmod +x "${APP}/Contents/MacOS/EnigmaXOR"
cp AppInfo.plist "${APP}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleGetInfoString Enigma XOR ${VERSION}" \
    "${APP}/Contents/Info.plist" 2>/dev/null || true

if [[ -f Assets/AppIcon.icns ]]; then
    cp Assets/AppIcon.icns "${APP}/Contents/Resources/"
fi
if [[ -f HELP.md ]]; then
    cp HELP.md "${APP}/Contents/Resources/"
fi
if [[ -f Examples/regression-v-ring-iv-plug-codebook.txt ]]; then
    cp Examples/regression-v-ring-iv-plug-codebook.txt "${APP}/Contents/Resources/"
fi

echo "Signing ${APP}..."
xattr -cr "${APP}" 2>/dev/null || true
codesign --force --sign - --identifier "${BUNDLE_ID}" --timestamp=none "${APP}/Contents/MacOS/EnigmaXOR"
codesign --force --sign - --identifier "${BUNDLE_ID}" --timestamp=none "${APP}"

plutil -lint "${APP}/Contents/Info.plist" >/dev/null
codesign --verify --verbose=2 "${APP}" 2>/dev/null || codesign --verify "${APP}"

if [[ -x /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister ]]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$(pwd)/${APP}" 2>/dev/null || true
fi

echo "Done: ${APP} (v${VERSION})"
if [[ "${LAUNCH}" == "true" ]]; then
    pkill -x EnigmaXOR 2>/dev/null || true
    sleep 0.2
    echo "Launching..."
    open "${APP}"
fi

#!/usr/bin/env bash
# release-dmg.sh — Package a signed .app into a drag-to-install DMG.
#
#   ./release-dmg.sh [path-to-.app]
#
# Defaults to the .app sitting beside this script. Everything else — app name,
# version, volume name, output filename, volume icon — is read out of the
# bundle, so the same script serves Tahoe5 and Tahoe21 unchanged.
#
# Modelled on Zudio/release-dmg.sh. Same light-grey background and drag-to-
# Applications layout, so all three apps install identically.
#
# NOTARIZATION: what matters is that the .app you pass in is already notarized
# AND stapled — that is what Gatekeeper checks when someone launches it, and a
# stapled ticket works offline. This script signs the DMG but does not notarize
# it, which matches how Zudio and GCI have always shipped. Notarizing the DMG
# too is Apple's belt-and-braces recommendation, not a requirement.
#
# Verify before shipping:
#   xcrun stapler validate <App>.app     -> "The validate action worked!"
#   spctl --assess --type exec -v <App>.app -> "source=Notarized Developer ID"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default to the single .app next to this script.
if [ $# -ge 1 ]; then
    APP_SRC="$1"
else
    APP_SRC=$(find "${SCRIPT_DIR}" -maxdepth 1 -name "*.app" | head -1)
fi

if [ ! -d "${APP_SRC}" ]; then
    echo "ERROR: App not found: ${APP_SRC:-<none beside this script>}"
    echo "Usage: $0 [path-to-.app]"
    exit 1
fi

APP_NAME=$(basename "${APP_SRC}" .app)
PLIST="${APP_SRC}/Contents/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${PLIST}")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${PLIST}")

TEAM_ID="K66MA9TR8Z"
SIGNING_IDENTITY="Developer ID Application: Zack Urlocker (${TEAM_ID})"
# Unversioned filename: releases are infrequent and a stable name means the
# download link on the site never has to change. The version still shows in
# the volume name when it's mounted, and in the app's About panel.
OUTPUT_DMG="${HOME}/Downloads/${APP_NAME}.dmg"

DMG_WORK="${TMPDIR:-/tmp}/${APP_NAME}DMG"
DMG_STAGING="${DMG_WORK}/staging"
DMG_BACKGROUND="${DMG_WORK}/background.png"

WINDOW_W=560
WINDOW_H=340
ICON_SIZE=100

echo ""
echo "==> App:     ${APP_NAME} ${VERSION} (build ${BUILD})"
echo "==> Source:  ${APP_SRC}"
echo "==> Output:  ${OUTPUT_DMG}"

# ---------------------------------------------------------------------------
# Step 1: Prerequisites
# ---------------------------------------------------------------------------
if ! command -v create-dmg &>/dev/null; then
    echo ""
    echo "ERROR: create-dmg not found. Install it with:"
    echo "  brew install create-dmg"
    exit 1
fi

# An ad-hoc signed app (the default for a local Debug build) launches here and
# nowhere else. Catch that now rather than after shipping the DMG.
echo ""
echo "==> [1/5] Checking app signature..."
# Capture first rather than piping into `grep -q`: grep exits on the first
# match, codesign then dies of SIGPIPE, and `set -o pipefail` reports the whole
# pipeline as failed even though the match succeeded.
SIG_INFO=$(codesign -dvvv "${APP_SRC}" 2>&1 || true)
if ! printf '%s\n' "${SIG_INFO}" | grep -q "^Authority=Developer ID Application"; then
    echo ""
    echo "ERROR: ${APP_NAME}.app is not signed with a Developer ID certificate."
    echo "       It is probably an ad-hoc signed Debug build, which will not run"
    echo "       on anyone else's Mac. Rebuild with:"
    echo ""
    echo "  xcodebuild -project ${APP_NAME}.xcodeproj -scheme ${APP_NAME} \\"
    echo "    -destination 'platform=macOS' -configuration Release \\"
    echo "    -derivedDataPath build-release CODE_SIGN_STYLE=Manual \\"
    echo "    CODE_SIGN_IDENTITY=\"Developer ID Application\" \\"
    echo "    DEVELOPMENT_TEAM=${TEAM_ID} ENABLE_HARDENED_RUNTIME=YES build"
    exit 1
fi
echo "    Developer ID signature present."

# ---------------------------------------------------------------------------
# Step 2: Background (light grey + dark grey arrow), generated with no deps
# ---------------------------------------------------------------------------
echo ""
echo "==> [2/5] Generating DMG background..."
rm -rf "${DMG_WORK}"
mkdir -p "${DMG_STAGING}"

DMG_BACKGROUND="${DMG_BACKGROUND}" python3 - <<'PYEOF'
import struct, zlib, os

# Canvas matches --window-size. Icons sit at x=130 and x=430, y=160, so the
# arrow runs between them.
W, H = 560, 340

# Light grey: Finder draws icon labels in black, so a dark background would
# make them unreadable.
BG = (210, 210, 215)
ARROW = (90, 90, 95)

SHAFT_X1, SHAFT_X2 = 195, 355
SHAFT_Y1, SHAFT_Y2 = 162, 178
HEAD_X1,  HEAD_X2  = 340, 395
HEAD_TIP_Y         = 170
HEAD_HALF          = 28

def in_arrow(x, y):
    if SHAFT_X1 <= x <= SHAFT_X2 and SHAFT_Y1 <= y <= SHAFT_Y2:
        return True
    if HEAD_X1 <= x <= HEAD_X2:
        frac = (HEAD_X2 - x) / (HEAD_X2 - HEAD_X1)
        if abs(y - HEAD_TIP_Y) <= HEAD_HALF * frac:
            return True
    return False

def write_png(path, pixels):
    def chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xffffffff
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', c)
    raw = b''.join(b'\x00' + bytes(row) for row in pixels)
    ihdr = struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0)
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n')
        f.write(chunk(b'IHDR', ihdr))
        f.write(chunk(b'IDAT', zlib.compress(raw, 9)))
        f.write(chunk(b'IEND', b''))

pixels = []
for y in range(H):
    row = []
    for x in range(W):
        row.extend(ARROW if in_arrow(x, y) else BG)
    pixels.append(row)

write_png(os.environ['DMG_BACKGROUND'], pixels)
print(f"    Background written: {os.environ['DMG_BACKGROUND']}")
PYEOF

# ---------------------------------------------------------------------------
# Step 3: Stage
# ---------------------------------------------------------------------------
echo ""
echo "==> [3/5] Staging app..."
cp -R "${APP_SRC}" "${DMG_STAGING}/${APP_NAME}.app"

# The app's own icon doubles as the mounted volume's icon, so the disk image
# looks like the game rather than a generic white drive.
VOLICON_ARGS=()
APP_ICNS="${APP_SRC}/Contents/Resources/AppIcon.icns"
if [ -f "${APP_ICNS}" ]; then
    VOLICON_ARGS=(--volicon "${APP_ICNS}")
    echo "    Volume icon: AppIcon.icns"
fi

# ---------------------------------------------------------------------------
# Step 4: Build the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [4/5] Building drag-to-install DMG..."
rm -f "${OUTPUT_DMG}"
create-dmg \
    --volname "${APP_NAME} ${VERSION}" \
    "${VOLICON_ARGS[@]}" \
    --background "${DMG_BACKGROUND}" \
    --window-pos 200 120 \
    --window-size ${WINDOW_W} ${WINDOW_H} \
    --icon-size ${ICON_SIZE} \
    --icon "${APP_NAME}.app" 130 160 \
    --app-drop-link 430 160 \
    --hide-extension "${APP_NAME}.app" \
    --no-internet-enable \
    "${OUTPUT_DMG}" \
    "${DMG_STAGING}/"

# ---------------------------------------------------------------------------
# Step 5: Sign the DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [5/5] Signing DMG..."
codesign --force --sign "${SIGNING_IDENTITY}" "${OUTPUT_DMG}"
codesign --verify "${OUTPUT_DMG}"
echo "    DMG signature verified OK."

rm -rf "${DMG_WORK}"

echo ""
echo "============================================================"
echo " Built: ${OUTPUT_DMG}"
echo ""
echo " The app inside is notarized and stapled, so it will launch on any Mac."
echo " Confirm with:"
echo "   xcrun stapler validate \"${APP_SRC}\""
echo "   spctl --assess --type exec -v \"${APP_SRC}\""
echo ""
echo " Optional (belt and braces — notarize the disk image itself):"
echo "   xcrun notarytool submit \"${OUTPUT_DMG}\" \\"
echo "     --keychain-profile \"<your-profile>\" --wait"
echo "   xcrun stapler staple \"${OUTPUT_DMG}\""
echo ""
echo "============================================================"
echo ""

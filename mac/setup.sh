#!/bin/bash
# setup.sh — regenerate Tahoe5.xcodeproj from project.yml.
#
#   bash setup.sh
#
# The .xcodeproj is generated, not checked in: project.yml is the source of
# truth. Re-run this after editing project.yml, or after adding a file to
# Sources/. Files added under Web/ need no regeneration — it is a folder
# reference, so whatever is in it gets bundled.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

step()  { echo -e "\n${CYAN}▶ $1${NC}"; }
ok()    { echo -e "${GREEN}  ✓ $1${NC}"; }
warn()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
fail()  { echo -e "${RED}  ✗ $1${NC}"; }

echo -e "${CYAN}"
echo "  ┌─────────────────────────────────────────┐"
echo "  │   TAHOE5 — Video Poker                  │"
echo "  │   Mac · iPad · iPhone                   │"
echo "  └─────────────────────────────────────────┘"
echo -e "${NC}"

# ── 1. Right directory? ──────────────────────────────────────────────────────
if [[ ! -f "project.yml" ]]; then
    fail "Run this from the T5/ project root (where project.yml lives)."
    exit 1
fi
ok "Project root confirmed"

# ── 2. Dependencies ──────────────────────────────────────────────────────────
step "Checking dependencies"
if ! xcode-select -p &>/dev/null; then
    fail "Xcode command line tools not found. Install with: xcode-select --install"
    exit 1
fi
ok "Xcode: $(xcode-select -p)"

if ! command -v xcodegen &>/dev/null; then
    warn "xcodegen not found — attempting install via Homebrew"
    if command -v brew &>/dev/null; then
        brew install xcodegen
        ok "xcodegen installed"
    else
        fail "Homebrew not found either. Install xcodegen manually:"
        fail "  brew install xcodegen   OR   mint install yonaskolb/XcodeGen"
        exit 1
    fi
else
    ok "xcodegen: $(xcodegen --version 2>/dev/null || echo found)"
fi

# ── 3. Web assets ────────────────────────────────────────────────────────────
step "Checking bundled game"
if [[ ! -f "Web/index.html" ]]; then
    fail "Web/index.html missing. Copy it from the Tahoe5 web repo:"
    fail "  cp -R ../Tahoe5/app/{index.html,styles.css,app.js,assets} Web/"
    exit 1
fi
ok "Web/: $(find Web -type f ! -name '.DS_Store' | wc -l | tr -d ' ') files"

# ── 4. Icons ─────────────────────────────────────────────────────────────────
step "Checking app icon"
if [[ ! -f "Sources/Assets.xcassets/AppIcon.appiconset/icon-1024.png" ]]; then
    warn "Icons missing — generating from the game logo"
    python3 make_icons.py || warn "Icon generation failed; see make_icons.py"
else
    ok "AppIcon present"
fi

# ── 5. Generate ──────────────────────────────────────────────────────────────
step "Generating Tahoe5.xcodeproj"
xcodegen generate
ok "Xcode project generated"

# ── 6. Done ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Setup complete. Next steps:${NC}"
echo ""
echo -e "  1. Open it:"
echo -e "     ${CYAN}open Tahoe5.xcodeproj${NC}"
echo ""
echo -e "  2. Pick a destination in the toolbar — My Mac, or an iPhone /"
echo -e "     iPad simulator — and press ⌘R."
echo ""
echo -e "  3. Sanity checks on first run:"
echo -e "     • Cards render and Deal works (custom scheme is serving Web/)"
echo -e "     • Sound plays after the first click (Web Audio unlocked)"
echo -e "     • About → the GitHub link opens in your browser, not in-app"
echo ""
echo -e "  4. To ship: bump CURRENT_PROJECT_VERSION in project.yml, re-run"
echo -e "     this script, then Product → Archive."
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

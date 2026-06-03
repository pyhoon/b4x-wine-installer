#!/bin/bash
#===============================================================================
# Repair missing B4J launcher
# Author: pyhoon (Aeric)
# Date: 03 June 2026
# License: MIT
#===============================================================================
set -e  # Exit on error

readonly GREEN='\033[0;32m'
readonly NC='\033[0m'
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
B4J_EXE="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4J/B4J.exe"
B4J_ICON_URL="https://raw.githubusercontent.com/pyhoon/b4x-wine-installer/refs/heads/main/icons/B4J.png"
B4J_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4j.desktop"
if [[ -f "$B4J_EXE" ]]; then
    ICON_PATH="${WINE_PREFIX}/drive_c/temp/b4j_icon.png"
    mkdir -p "$(dirname "$ICON_PATH")"
    download_file "${B4J_ICON_URL}" "$ICON_PATH" 2>/dev/null || ICON_PATH=""
    LOCAL_ICON="${HOME}/.local/share/icons/b4j.png"
    mkdir -p "$(dirname "$LOCAL_ICON")"
    [[ -f "$ICON_PATH" ]] && cp "$ICON_PATH" "$LOCAL_ICON" 2>/dev/null || true
    
        cat > "$B4J_DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Version=1.0
Name=B4J
Comment=B4J IDE - Run via Wine
Exec=env WINEPREFIX="${WINE_PREFIX}" wine "${B4J_EXE}"
Path=${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4J
Icon=${LOCAL_ICON}
Terminal=false
Type=Application
Categories=Development;IDE;
Keywords=B4J;B4X;Java;IDE;Basic;
StartupNotify=true
EOF
        chmod +x "$B4J_DESKTOP_ENTRY"
        update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
        cp "$B4J_DESKTOP_ENTRY" "${HOME}/Desktop/" 2>/dev/null && chmod +x "${HOME}/Desktop/b4j.desktop" 2>/dev/null || true
        log_success "B4J desktop launcher created"
    fi

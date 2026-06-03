#!/bin/bash
#===============================================================================
# Repair missing B4A launcher
# Author: pyhoon (Aeric)
# Date: 03 June 2026
# License: MIT
#===============================================================================
set -e  # Exit on error

readonly GREEN='\033[0;32m'
readonly NC='\033[0m'
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }

WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
B4A_EXE="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4A/B4A.exe"
B4A_ICON_URL="https://raw.githubusercontent.com/pyhoon/b4x-wine-installer/refs/heads/main/icons/B4A.png"
B4A_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4a.desktop"
if [[ -f "$B4A_EXE" ]]; then
    ICON_PATH="${WINE_PREFIX}/drive_c/temp/b4a_icon.png"
    mkdir -p "$(dirname "$ICON_PATH")"
    download_file "${B4A_ICON_URL}" "$ICON_PATH" 2>/dev/null || ICON_PATH=""
    LOCAL_ICON="${HOME}/.local/share/icons/b4a.png"
    mkdir -p "$(dirname "$LOCAL_ICON")"
    [[ -f "$ICON_PATH" ]] && cp "$ICON_PATH" "$LOCAL_ICON" 2>/dev/null || true
    
    cat > "$B4A_DESKTOP_ENTRY" <<EOF
[Desktop Entry]
Version=1.0
Name=B4A
Comment=B4A IDE - Run via Wine
Exec=env WINEPREFIX="${WINE_PREFIX}" wine "${B4A_EXE}"
Path=${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4A
Icon=${LOCAL_ICON}
Terminal=false
Type=Application
Categories=Development;IDE;
Keywords=B4A;B4X;Java;IDE;Basic;
StartupNotify=true
EOF
        chmod +x "$B4A_DESKTOP_ENTRY"
        update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
        cp "$B4A_DESKTOP_ENTRY" "${HOME}/Desktop/" 2>/dev/null && chmod +x "${HOME}/Desktop/b4a.desktop" 2>/dev/null || true
        log_success "B4A desktop launcher created"
    fi

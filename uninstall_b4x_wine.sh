#!/bin/bash
#===============================================================================
# B4X Wine Uninstaller for Linux Mint
# Safely removes B4A, B4J, Wine prefix, launchers, and optional folders
# Author: pyhoon (Aeric)
# Date: 28 May 2026 (updated on 03 June 2026)
# License: MIT
#===============================================================================
set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION (Matches install_b4x_wine.sh)
#-------------------------------------------------------------------------------
WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
B4A_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4a.desktop"
B4J_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4j.desktop"
B4X_PROJECTS_DIR="${HOME}/B4X_Projects"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Flags
DRY_RUN=false
FORCE=false
KEEP_PROJECTS=false
KEEP_WINE=false

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
log_action()  { echo -e "${CYAN}[→]${NC} $1"; }

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Safely uninstall B4A and B4J Wine installations from Linux Mint.

OPTIONS:
  -h, --help          Show this help message and exit
  -d, --dry-run       Preview what will be removed without deleting
  -f, --force         Skip confirmation prompts (use with caution!)
  -p, --keep-projects Keep the ~/B4X_Projects folder (default: remove)
  -w, --keep-wine     Don't remove Wine/Winetricks system packages
  -v, --verbose       Show detailed removal actions
EOF
    exit 0
}

confirm() {
    [[ "$FORCE" == "true" ]] && return 0
    local prompt="${1:-Are you sure?}"
    echo -ne "${YELLOW}${prompt} [y/N]: ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy](es)?$ ]]
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help) usage ;;
            -d|--dry-run) DRY_RUN=true; log_info "🔍 DRY RUN MODE - No changes will be made" ;;
            -f|--force) FORCE=true; log_warn "⚠️ FORCE MODE - Skipping confirmations" ;;
            -p|--keep-projects) KEEP_PROJECTS=true; log_info "📁 Will keep ${B4X_PROJECTS_DIR}" ;;
            -w|--keep-wine) KEEP_WINE=true; log_info "🍷 Will keep Wine system packages" ;;
            -v|--verbose) set -x ;;
            *) log_error "Unknown option: $1"; usage ;;
        esac
        shift
    done
}

get_prefix_size() {
    [[ -d "$WINE_PREFIX" ]] && du -sh "$WINE_PREFIX" 2>/dev/null | cut -f1 || echo "0B"
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
parse_args "$@"

echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  B4X Wine Uninstaller for Linux Mint                   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"

if [[ ! -d "$WINE_PREFIX" ]]; then
    log_warn "Wine prefix not found: ${WINE_PREFIX}"
    [[ "$FORCE" != "true" ]] && confirm "Continue anyway to clean up leftover files?" || exit 0
fi

log_info "Summary of items to be removed:"
echo -e "  ${CYAN}• Wine prefix:${NC} ${WINE_PREFIX} ($(get_prefix_size))"
echo -e "  ${CYAN}• Desktop launchers:${NC} b4a.desktop, b4j.desktop"
[[ "$KEEP_PROJECTS" != "true" ]] && echo -e "  ${CYAN}• Projects folder:${NC} ${B4X_PROJECTS_DIR}"
echo -e "  ${CYAN}• Wine C:\\Additional Libraries:${NC} (removed with prefix)"
[[ "$KEEP_WINE" != "true" ]] && echo -e "  ${CYAN}• System packages:${NC} winehq-stable, winetricks"
echo ""

if [[ "$DRY_RUN" != "true" && "$FORCE" != "true" ]]; then
    confirm "⚠️ This will permanently delete B4X and all associated data" || exit 0
fi

# 1. Stop Wine processes
log_action "Stopping Wine processes..."
[[ "$DRY_RUN" != "true" ]] && { wineserver -k 2>/dev/null || true; sleep 1; log_success "Wine processes terminated"; } || echo "  [DRY RUN] Would kill Wine processes"

# 2. Remove Launchers & Icons
log_action "Removing desktop launchers & icons..."
if [[ "$DRY_RUN" != "true" ]]; then
    for f in "$B4A_DESKTOP_ENTRY" "$B4J_DESKTOP_ENTRY" "${HOME}/Desktop/b4a.desktop" "${HOME}/Desktop/b4j.desktop"; do
        [[ -f "$f" ]] && rm -f "$f" && log_success "Removed: $f"
    done
    for icon in "${HOME}/.local/share/icons/b4a.png" "${HOME}/.local/share/icons/b4j.png"; do
        [[ -f "$icon" ]] && rm -f "$icon" && log_success "Removed: $icon"
    done
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
    log_success "Desktop database updated"
else
    echo "  [DRY RUN] Would remove launchers & icons"
fi

# 3. Remove Wine Prefix
log_action "Removing Wine prefix: ${WINE_PREFIX}"
if [[ "$DRY_RUN" != "true" ]]; then
    [[ -d "$WINE_PREFIX" ]] && rm -rf "$WINE_PREFIX" && log_success "Removed Wine prefix ($(get_prefix_size) freed)"
else
    echo "  [DRY RUN] Would remove: ${WINE_PREFIX}"
fi

# 4. Remove Projects (Optional)
if [[ "$KEEP_PROJECTS" != "true" ]]; then
    log_action "Removing Projects folder: ${B4X_PROJECTS_DIR}"
    if [[ "$DRY_RUN" != "true" && -d "$B4X_PROJECTS_DIR" ]]; then
        file_count=$(find "$B4X_PROJECTS_DIR" -type f 2>/dev/null | wc -l)
        [[ $file_count -gt 0 ]] && log_warn "Projects folder contains ${file_count} file(s) - deleting permanently!"
        rm -rf "$B4X_PROJECTS_DIR" && log_success "Removed: ${B4X_PROJECTS_DIR}"
    else
        [[ -d "$B4X_PROJECTS_DIR" ]] && echo "  [DRY RUN] Would remove: ${B4X_PROJECTS_DIR}"
    fi
else
    log_info "Keeping Projects folder: ${B4X_PROJECTS_DIR}"
fi

# 5. Remove Wine Packages (Optional)
if [[ "$KEEP_WINE" != "true" && "$DRY_RUN" != "true" ]]; then
    if [[ "$FORCE" == "true" ]] || confirm "Also remove Wine and Winetricks system packages?"; then
        log_action "Removing Wine system packages..."
        sudo apt purge -y winehq-stable winetricks 2>/dev/null || true
        sudo apt autoremove -y -qq 2>/dev/null || true
        log_success "Wine system packages removed"
    else
        log_info "Keeping Wine system packages"
    fi
elif [[ "$KEEP_WINE" != "true" && "$DRY_RUN" == "true" ]]; then
    echo "  [DRY RUN] Would remove: winehq-stable, winetricks"
fi

# 6. Cleanup Residuals
log_action "Cleaning up residual files..."
if [[ "$DRY_RUN" != "true" ]]; then
    find "${HOME}" -maxdepth 3 -type f \( -name "*B4A*" -o -name "*b4a*" -o -name "*B4J*" -o -name "*b4j*" \) -regex ".*\.(exe|zip|tmp|log)$" 2>/dev/null | while read -r file; do
        rm -f "$file" 2>/dev/null && log_info "Removed residual: $file"
    done
    log_success "Residual cleanup completed"
else
    echo "  [DRY RUN] Would clean residual B4X-related temp files"
fi

# Final Summary
echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GREEN}  ✓ DRY RUN COMPLETE - No changes were made${NC}"
    echo -e "\n${YELLOW}To perform the actual uninstall, run:${NC} ./$(basename "$0") (without --dry-run)"
else
    echo -e "${GREEN}  ✓ B4X Wine Uninstall Complete!${NC}"
    echo -e "\n${YELLOW}📋 Notes:${NC}"
    echo "  • Your B4X source code projects are safe if you used --keep-projects"
    echo "  • Wine can be reinstalled anytime: sudo apt install winehq-stable"
    echo "  • To reinstall: ./install_b4x_wine.sh"
fi
echo -e "\n${GREEN}✨ Thank you for using B4X on Linux! Come back anytime! 🚀${NC}\n"
exit 0
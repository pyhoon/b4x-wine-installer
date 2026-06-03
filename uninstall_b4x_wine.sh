#!/bin/bash
#===============================================================================
# B4X Wine Uninstaller for Linux Mint
# Supports selective removal of B4A, B4J, both, or everything (prefix + Wine)
# Author: pyhoon (Aeric)
# AI Assistant: Qwen3.6 Plus
# Date: 28 May 2026 (Updated 03 June 2026)
# License: MIT
#===============================================================================
set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION (Matches install_b4x_wine.sh)
#-------------------------------------------------------------------------------
WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
B4A_INSTALL_DIR="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4A"
B4J_INSTALL_DIR="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4J"
B4A_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4a.desktop"
B4J_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4j.desktop"
B4A_ICON="${HOME}/.local/share/icons/b4a.png"
B4J_ICON="${HOME}/.local/share/icons/b4j.png"
B4X_PROJECTS_DIR="${B4X_PROJECTS_DIR:-${HOME}/B4X_Projects}"

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
UNINSTALL_B4A=false
UNINSTALL_B4J=false
UNINSTALL_ALL=false

log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
log_action()  { echo -e "${CYAN}[→]${NC} $1"; }

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]
Selectively uninstall B4A, B4J, both, or the entire Wine environment.

OPTIONS:
  --b4a       Uninstall B4A only (keeps B4J & shared prefix)
  --b4j       Uninstall B4J only (keeps B4A & shared prefix)
  --both      Uninstall both IDEs (keeps shared prefix)
  --all       Uninstall everything (prefix, IDEs, launchers, optional Wine)
  -d, --dry-run       Preview what will be removed without deleting
  -f, --force         Skip confirmation prompts (use with caution!)
  -p, --keep-projects Keep the ~/B4X_Projects folder (default: remove if --all)
  -w, --keep-wine     Don't remove Wine/Winetricks system packages
  -v, --verbose       Show detailed removal actions
  -h, --help          Show this help message
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

get_prefix_size() {
    [[ -d "$WINE_PREFIX" ]] && du -sh "$WINE_PREFIX" 2>/dev/null | cut -f1 || echo "0B"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --b4a) UNINSTALL_B4A=true; shift ;;
            --b4j) UNINSTALL_B4J=true; shift ;;
            --both) UNINSTALL_B4A=true; UNINSTALL_B4J=true; shift ;;
            --all|--everything) UNINSTALL_ALL=true; shift ;;
            -d|--dry-run) DRY_RUN=true; log_info "🔍 DRY RUN MODE - No changes will be made" ;;
            -f|--force) FORCE=true; log_warn "⚠️ FORCE MODE - Skipping confirmations" ;;
            -p|--keep-projects) KEEP_PROJECTS=true; log_info "📁 Will keep ${B4X_PROJECTS_DIR}" ;;
            -w|--keep-wine) KEEP_WINE=true; log_info "🍷 Will keep Wine system packages" ;;
            -v|--verbose) set -x ;;
            -h|--help) usage ;;
            *) log_error "Unknown option: $1"; usage ;;
        esac
    done
}

select_target() {
    if [[ "$UNINSTALL_B4A" == true || "$UNINSTALL_B4J" == true || "$UNINSTALL_ALL" == true ]]; then
        return
    fi

    echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  Select What to Uninstall                              ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"
    
    PS3="Enter choice: "
    options=("B4A Only" "B4J Only" "Both B4A & B4J" "Everything (Prefix + Wine)" "Quit")
    select opt in "${options[@]}"; do
        case $opt in
            "B4A Only") UNINSTALL_B4A=true; break ;;
            "B4J Only") UNINSTALL_B4J=true; break ;;
            "Both B4A & B4J") UNINSTALL_B4A=true; UNINSTALL_B4J=true; break ;;
            "Everything (Prefix + Wine)") UNINSTALL_ALL=true; break ;;
            "Quit") log_info "Uninstall cancelled."; exit 0 ;;
            *) log_warn "Invalid choice. Try again." ;;
        esac
    done
    
    if [[ "$UNINSTALL_B4A" == false && "$UNINSTALL_B4J" == false && "$UNINSTALL_ALL" == false ]]; then
        log_error "No target selected."
        exit 1
    fi
}

#-------------------------------------------------------------------------------
# UNINSTALL FUNCTIONS
#-------------------------------------------------------------------------------
remove_product() {
    local product="$1" install_dir="$2" desktop_entry="$3" icon="$4"
    log_action "Removing ${product}..."
    if [[ "$DRY_RUN" != "true" ]]; then
        [[ -d "$install_dir" ]] && rm -rf "$install_dir" && log_success "Removed: $install_dir" || log_warn "Not found: $install_dir"
        [[ -f "$desktop_entry" ]] && rm -f "$desktop_entry" && log_success "Removed launcher: $desktop_entry"
        rm -f "${HOME}/Desktop/$(basename "$desktop_entry")" 2>/dev/null || true
        [[ -f "$icon" ]] && rm -f "$icon" && log_success "Removed icon: $icon"
        update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
    else
        echo "  [DRY RUN] Would remove ${product} files, launcher, and icon"
    fi
}

do_partial_uninstall() {
    log_warn "⚠️ Partial Uninstall Mode"
    log_info "This removes only the selected IDE(s), launchers, and icons."
    log_info "The shared Wine prefix, dependencies (.NET, DXVK, JDK), and config files remain intact."
    log_info "This is safe if you plan to reinstall or use the other IDE."
    echo ""

    [[ "$UNINSTALL_B4A" == true ]] && remove_product "B4A" "$B4A_INSTALL_DIR" "$B4A_DESKTOP_ENTRY" "$B4A_ICON"
    [[ "$UNINSTALL_B4J" == true ]] && remove_product "B4J" "$B4J_INSTALL_DIR" "$B4J_DESKTOP_ENTRY" "$B4J_ICON"

    # Clean empty parent directories if possible
    if [[ "$DRY_RUN" != "true" ]]; then
        rmdir "${WINE_PREFIX}/drive_c/Program Files/Anywhere Software" 2>/dev/null || true
        rmdir "${WINE_PREFIX}/drive_c/Program Files" 2>/dev/null || true
    fi
}

do_full_uninstall() {
    log_action "Stopping Wine processes..."
    [[ "$DRY_RUN" != "true" ]] && { wineserver -k 2>/dev/null || true; sleep 1; log_success "Wine processes terminated"; } || echo "  [DRY RUN] Would kill Wine processes"

    # Remove ALL launchers & icons
    log_action "Removing all desktop launchers & icons..."
    if [[ "$DRY_RUN" != "true" ]]; then
        for f in "$B4A_DESKTOP_ENTRY" "$B4J_DESKTOP_ENTRY" "${HOME}/Desktop/b4a.desktop" "${HOME}/Desktop/b4j.desktop"; do
            [[ -f "$f" ]] && rm -f "$f" && log_success "Removed: $f"
        done
        for icon in "$B4A_ICON" "$B4J_ICON"; do
            [[ -f "$icon" ]] && rm -f "$icon" && log_success "Removed: $icon"
        done
        update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
        log_success "Desktop database updated"
    else
        echo "  [DRY RUN] Would remove all launchers & icons"
    fi

    # Remove Wine Prefix
    log_action "Removing Wine prefix: ${WINE_PREFIX} ($(get_prefix_size))"
    if [[ "$DRY_RUN" != "true" ]]; then
        [[ -d "$WINE_PREFIX" ]] && rm -rf "$WINE_PREFIX" && log_success "Removed Wine prefix"
    else
        echo "  [DRY RUN] Would remove: ${WINE_PREFIX}"
    fi

    # Remove Projects (Optional)
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

    # Remove Wine Packages (Optional)
    if [[ "$KEEP_WINE" != "true" ]]; then
        echo ""
        if [[ "$FORCE" == "true" ]] || confirm "Also remove Wine and Winetricks system packages?"; then
            log_action "Removing Wine system packages..."
            if [[ "$DRY_RUN" != "true" ]]; then
                other_prefixes=$(find "${HOME}" -maxdepth 2 \( -name ".wine" -o -name ".wine_*" \) 2>/dev/null | wc -l)
                if [[ $other_prefixes -gt 0 ]]; then
                    log_warn "Found ${other_prefixes} other Wine prefix(es) - keeping Wine packages!"
                else
                    sudo apt purge -y winehq-stable winetricks 2>/dev/null || true
                    sudo apt autoremove -y -qq 2>/dev/null || true
                    log_success "Wine system packages removed"
                fi
            else
                echo "  [DRY RUN] Would remove: winehq-stable, winetricks"
            fi
        else
            log_info "Keeping Wine system packages (as requested)"
        fi
    else
        log_info "Keeping Wine system packages (as requested)"
    fi
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
parse_args "$@"
select_target

echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  B4X Wine Uninstaller for Linux Mint                   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"

if [[ ! -d "$WINE_PREFIX" ]]; then
    log_warn "Wine prefix not found: ${WINE_PREFIX}"
    [[ "$FORCE" != "true" ]] && confirm "Continue anyway to clean up leftover files?" || exit 0
fi

log_info "Summary of actions:"
[[ "$UNINSTALL_B4A" == true ]] && echo -e "  ${CYAN}• Uninstall B4A${NC}"
[[ "$UNINSTALL_B4J" == true ]] && echo -e "  ${CYAN}• Uninstall B4J${NC}"
[[ "$UNINSTALL_ALL" == true ]] && echo -e "  ${CYAN}• Remove Entire Prefix & Environment${NC}"
[[ "$UNINSTALL_ALL" != "true" ]] && echo -e "  ${CYAN}• Keep Shared Wine Prefix & Dependencies${NC}"
[[ "$KEEP_PROJECTS" != "true" && "$UNINSTALL_ALL" == true ]] && echo -e "  ${CYAN}• Remove Projects Folder${NC}"
[[ "$KEEP_WINE" != "true" && "$UNINSTALL_ALL" == true ]] && echo -e "  ${CYAN}• Remove Wine System Packages (if safe)${NC}"
echo ""

if [[ "$DRY_RUN" != "true" && "$FORCE" != "true" ]]; then
    confirm "⚠️ This will permanently delete selected components" || exit 0
fi

# Execute selected uninstall path
if [[ "$UNINSTALL_ALL" == true ]]; then
    do_full_uninstall
else
    do_partial_uninstall
fi

# Cleanup Residuals (Always runs unless dry-run)
log_action "Cleaning up residual temp files..."
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
    echo -e "${GREEN}  ✓ Uninstall Complete!${NC}"
    echo -e "\n${YELLOW}📋 Notes:${NC}"
    if [[ "$UNINSTALL_ALL" == true ]]; then
        echo "  • Wine prefix, launchers, and selected components removed"
        [[ "$KEEP_PROJECTS" != "true" ]] && echo "  • Projects folder removed"
        echo "  • Wine can be reinstalled anytime: sudo apt install winehq-stable"
    else
        echo "  • Selected IDE(s) removed"
        echo "  • Shared Wine prefix, JDK, Android SDK, and dependencies preserved"
        echo "  • You can safely run ./install_b4x_wine.sh to add back the removed IDE"
    fi
    echo -e "\n${GREEN}✨ Thank you for using B4X on Linux! Come back anytime! 🚀${NC}"
fi
echo ""
exit 0
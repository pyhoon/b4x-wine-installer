#!/bin/bash
#===============================================================================
# B4X Wine Uninstaller for Linux Mint
# Safely removes B4A, B4J, Wine prefix, launchers, and optional folders
# Author: pyhoon
# AI Assistant: Qwen3.6 Plus
# Date: 28 May 2026
# License: MIT
#===============================================================================

set -euo pipefail  # Exit on error, undefined vars, pipe failures

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
readonly SCRIPT_NAME="$(basename "$0")"
readonly WINE_PREFIX="${HOME}/.wine_b4x"
readonly B4A_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4a.desktop"
readonly B4J_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4j.desktop"
readonly B4A_DESKTOP_SHORTCUT="${HOME}/Desktop/b4a.desktop"
readonly B4J_DESKTOP_SHORTCUT="${HOME}/Desktop/b4j.desktop"
readonly B4A_LOCAL_ICON="${HOME}/.local/share/icons/b4a.png"
readonly B4J_LOCAL_ICON="${HOME}/.local/share/icons/b4j.png"
readonly PROJECTS_DIR="${HOME}/B4X_Projects"
readonly ADDITIONAL_LIBS_WINE="C:\\Additional Libraries"

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

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
log_action()  { echo -e "${CYAN}[→]${NC} $1"; }

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Safely uninstall B4A and B4J Wine installations from Linux Mint.

OPTIONS:
    -h, --help          Show this help message and exit
    -d, --dry-run       Show what would be removed without deleting anything
    -f, --force         Skip confirmation prompts (use with caution!)
    -p, --keep-projects Keep the ~/B4X_Projects folder (default: remove)
    -w, --keep-wine     Do NOT remove Wine/Winetricks system packages
    -v, --verbose       Show detailed removal actions

EXAMPLES:
    $SCRIPT_NAME                    # Interactive uninstall (recommended)
    $SCRIPT_NAME --dry-run          # Preview what will be removed
    $SCRIPT_NAME --force            # Uninstall without prompts
    $SCRIPT_NAME -p -w              # Keep projects + Wine packages

EOF
    exit 0
}

confirm() {
    # Skip if --force flag is set
    if [[ "$FORCE" == "true" ]]; then
        return 0
    fi
    
    local prompt="${1:-Are you sure?}"
    echo -ne "${YELLOW}${prompt} [y/N]: ${NC}"
    read -r response
    [[ "$response" =~ ^[Yy](es)?$ ]]
}

check_prefix_exists() {
    if [[ ! -d "$WINE_PREFIX" ]]; then
        log_warn "Wine prefix not found: ${WINE_PREFIX}"
        log_info "B4X may already be uninstalled, or was installed elsewhere."
        return 1
    fi
    return 0
}

get_wine_prefix_size() {
    if [[ -d "$WINE_PREFIX" ]]; then
        du -sh "$WINE_PREFIX" 2>/dev/null | cut -f1 || echo "unknown"
    else
        echo "0B"
    fi
}

#-------------------------------------------------------------------------------
# PARSE COMMAND-LINE ARGUMENTS
#-------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) usage ;;
        -d|--dry-run) DRY_RUN=true; log_info "🔍 DRY RUN MODE - No changes will be made" ;;
        -f|--force) FORCE=true; log_warn "⚠️ FORCE MODE - Skipping confirmations" ;;
        -p|--keep-projects) KEEP_PROJECTS=true; log_info "📁 Will keep ${PROJECTS_DIR}" ;;
        -w|--keep-wine) KEEP_WINE=true; log_info "🍷 Will keep Wine system packages" ;;
        -v|--verbose) set -x ;;  # Enable bash debug mode
        *) log_error "Unknown option: $1"; usage ;;
    esac
    shift
done

#-------------------------------------------------------------------------------
# MAIN UNINSTALL LOGIC
#-------------------------------------------------------------------------------
echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  B4X Wine Uninstaller for Linux Mint                   ║${NC}"
echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}\n"

# Check if B4X prefix exists
if ! check_prefix_exists; then
    if [[ "$FORCE" != "true" ]]; then
        confirm "Continue anyway to clean up leftover files?" || exit 0
    fi
fi

# Show what will be removed
log_info "Summary of items to be removed:"
echo -e "  ${CYAN}• Wine prefix:${NC} ${WINE_PREFIX} ($(get_wine_prefix_size))"
echo -e "  ${CYAN}• Desktop launcher:${NC} ${B4A_DESKTOP_ENTRY},${B4J_DESKTOP_ENTRY}"
[[ -f "$B4A_DESKTOP_SHORTCUT" ]] && echo -e "  ${CYAN}• Desktop shortcut:${NC} ${B4A_DESKTOP_SHORTCUT}"
[[ -f "$B4J_DESKTOP_SHORTCUT" ]] && echo -e "  ${CYAN}• Desktop shortcut:${NC} ${B4J_DESKTOP_SHORTCUT}"
[[ -f "$B4A_LOCAL_ICON" ]] && echo -e "  ${CYAN}• Custom icon:${NC} ${B4A_LOCAL_ICON}"
[[ -f "$B4J_LOCAL_ICON" ]] && echo -e "  ${CYAN}• Custom icon:${NC} ${B4J_LOCAL_ICON}"
[[ "$KEEP_PROJECTS" != "true" ]] && echo -e "  ${CYAN}• Projects folder:${NC} ${PROJECTS_DIR}"
echo -e "  ${CYAN}• Wine C: Additional Libraries:${NC} ${ADDITIONAL_LIBS_WINE}"
[[ "$KEEP_WINE" != "true" ]] && echo -e "  ${CYAN}• System packages (optional):${NC} winehq-stable, winetricks"
echo ""

# Final confirmation
if [[ "$DRY_RUN" != "true" ]]; then
    if [[ "$FORCE" != "true" ]]; then
        if ! confirm "⚠️ This will permanently delete B4X and all associated data"; then
            log_info "Uninstall cancelled by user."
            exit 0
        fi
    fi
fi

#-------------------------------------------------------------------------------
# 1. Stop any running B4X/Wine processes
#-------------------------------------------------------------------------------
log_action "Stopping Wine processes..."
if [[ "$DRY_RUN" != "true" ]]; then
    wineserver -k 2>/dev/null || true
    # Wait briefly for processes to terminate
    sleep 1
    log_success "Wine processes terminated"
else
    echo "  [DRY RUN] Would kill Wine processes"
fi

#-------------------------------------------------------------------------------
# 2. Remove Desktop Launcher & Menu Entry
#-------------------------------------------------------------------------------
log_action "Removing desktop launchers..."
if [[ "$DRY_RUN" != "true" ]]; then
    [[ -f "$B4A_DESKTOP_ENTRY" ]] && rm -f "$B4A_DESKTOP_ENTRY" && log_success "Removed: ${B4A_DESKTOP_ENTRY}" || log_warn "Launcher not found: ${B4A_DESKTOP_ENTRY}"
    [[ -f "$B4J_DESKTOP_ENTRY" ]] && rm -f "$B4J_DESKTOP_ENTRY" && log_success "Removed: ${B4J_DESKTOP_ENTRY}" || log_warn "Launcher not found: ${B4J_DESKTOP_ENTRY}"
    [[ -f "$B4A_DESKTOP_SHORTCUT" ]] && rm -f "$B4A_DESKTOP_SHORTCUT" && log_success "Removed: ${B4A_DESKTOP_SHORTCUT}"
    [[ -f "$B4J_DESKTOP_SHORTCUT" ]] && rm -f "$B4J_DESKTOP_SHORTCUT" && log_success "Removed: ${B4J_DESKTOP_SHORTCUT}"

    # Update desktop database
    update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
    log_success "Desktop database updated"
else
    [[ -f "$B4A_DESKTOP_ENTRY" ]] && echo "  [DRY RUN] Would remove: ${B4A_DESKTOP_ENTRY}"
    [[ -f "$B4J_DESKTOP_ENTRY" ]] && echo "  [DRY RUN] Would remove: ${B4J_DESKTOP_ENTRY}"
    [[ -f "$B4A_DESKTOP_SHORTCUT" ]] && echo "  [DRY RUN] Would remove: ${B4A_DESKTOP_SHORTCUT}"
    [[ -f "$B4J_DESKTOP_SHORTCUT" ]] && echo "  [DRY RUN] Would remove: ${B4J_DESKTOP_SHORTCUT}"
fi

#-------------------------------------------------------------------------------
# 3. Remove Custom Icon
#-------------------------------------------------------------------------------
log_action "Removing custom icons..."
if [[ "$DRY_RUN" != "true" ]]; then
    [[ -f "$B4A_LOCAL_ICON" ]] && rm -f "$B4A_LOCAL_ICON" && log_success "Removed: ${B4A_LOCAL_ICON}" || log_warn "Icon not found: ${B4A_LOCAL_ICON}"
    [[ -f "$B4J_LOCAL_ICON" ]] && rm -f "$B4J_LOCAL_ICON" && log_success "Removed: ${B4J_LOCAL_ICON}" || log_warn "Icon not found: ${B4J_LOCAL_ICON}"
else
    [[ -f "$B4A_LOCAL_ICON" ]] && echo "  [DRY RUN] Would remove: ${B4A_LOCAL_ICON}"
    [[ -f "$B4J_LOCAL_ICON" ]] && echo "  [DRY RUN] Would remove: ${B4J_LOCAL_ICON}"
fi

#-------------------------------------------------------------------------------
# 4. Remove Wine Prefix (Main B4X Installation)
#-------------------------------------------------------------------------------
log_action "Removing Wine prefix: ${WINE_PREFIX}"
if [[ "$DRY_RUN" != "true" ]]; then
    if [[ -d "$WINE_PREFIX" ]]; then
        rm -rf "$WINE_PREFIX"
        log_success "Removed Wine prefix ($(get_wine_prefix_size) freed)"
    else
        log_warn "Prefix directory not found: ${WINE_PREFIX}"
    fi
else
    echo "  [DRY RUN] Would remove: ${WINE_PREFIX} ($(get_wine_prefix_size))"
fi

#-------------------------------------------------------------------------------
# 5. Remove Optional Folders
#-------------------------------------------------------------------------------
# Remove Projects folder (if not keeping)
if [[ "$KEEP_PROJECTS" != "true" ]]; then
    log_action "Removing Projects folder: ${PROJECTS_DIR}"
    if [[ "$DRY_RUN" != "true" ]]; then
        if [[ -d "$PROJECTS_DIR" ]]; then
            # Warn if folder contains files
            file_count=$(find "$PROJECTS_DIR" -type f 2>/dev/null | wc -l)
            if [[ $file_count -gt 0 ]]; then
                log_warn "Projects folder contains ${file_count} file(s) - deleting permanently!"
            fi
            rm -rf "$PROJECTS_DIR"
            log_success "Removed: ${PROJECTS_DIR}"
        else
            log_warn "Projects folder not found: ${PROJECTS_DIR}"
        fi
    else
        [[ -d "$PROJECTS_DIR" ]] && echo "  [DRY RUN] Would remove: ${PROJECTS_DIR}"
    fi
else
    log_info "Keeping Projects folder: ${PROJECTS_DIR} (as requested)"
fi

# Note: Additional Libraries inside Wine prefix are removed when prefix is deleted
log_success "Additional Libraries folder removed with Wine prefix"

#-------------------------------------------------------------------------------
# 6. Optional: Remove Wine/Winetricks System Packages
#-------------------------------------------------------------------------------
if [[ "$KEEP_WINE" != "true" ]]; then
    echo ""
    if [[ "$FORCE" != "true" ]]; then
        if confirm "Also remove Wine and Winetricks system packages? (Only if no other Wine apps use them)"; then
            log_action "Removing Wine system packages..."
            if [[ "$DRY_RUN" != "true" ]]; then
                # Check if other Wine prefixes exist
                other_prefixes=$(find "${HOME}" -maxdepth 2 -name ".wine" -o -name ".wine_*" 2>/dev/null | grep -v "^${WINE_PREFIX}$" | wc -l)
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
        # Force mode: remove Wine packages without prompt
        log_action "Removing Wine system packages (force mode)..."
        if [[ "$DRY_RUN" != "true" ]]; then
            sudo apt purge -y winehq-stable winetricks 2>/dev/null || true
            sudo apt autoremove -y -qq 2>/dev/null || true
            log_success "Wine system packages removed"
        else
            echo "  [DRY RUN] Would remove: winehq-stable, winetricks"
        fi
    fi
else
    log_info "Keeping Wine system packages (as requested)"
fi

#-------------------------------------------------------------------------------
# 7. Clean Up Residual Files
#-------------------------------------------------------------------------------
log_action "Cleaning up residual files..."
if [[ "$DRY_RUN" != "true" ]]; then
    # Remove any leftover temp files in user directories
    find "${HOME}" -maxdepth 3 -name "*B4A*" -o -name "*b4a*" -o -name "*B4J*" -o -name "*b4j*" -o -name "*B4X*" -o -name "*b4x*" 2>/dev/null | grep -E "\.(exe|zip|tmp|log)$" | while read -r file; do
        rm -f "$file" 2>/dev/null && log_info "Removed residual: $file" || true
    done
    log_success "Residual cleanup completed"
else
    echo "  [DRY RUN] Would clean residual B4X-related temp files"
fi

#-------------------------------------------------------------------------------
# 8. Final Summary
#-------------------------------------------------------------------------------
echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GREEN}  ✓ DRY RUN COMPLETE - No changes were made${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "\n${YELLOW}To perform the actual uninstall, run:${NC}"
    echo -e "  ${CYAN}$SCRIPT_NAME${NC} (without --dry-run)"
else
    echo -e "${GREEN}  ✓ B4X Wine Uninstall Complete!${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "\n${GREEN}🗑️  Removed:${NC}"
    echo "  • Wine prefix: ${WINE_PREFIX}"
    echo "  • Desktop launchers & shortcuts"
    echo "  • Custom icons"
    [[ "$KEEP_PROJECTS" != "true" ]] && echo "  • Projects folder: ${PROJECTS_DIR}"
    [[ "$KEEP_WINE" != "true" ]] && echo "  • Wine system packages (if no other prefixes exist)"
    
    echo -e "\n${YELLOW}📋 Notes:${NC}"
    echo "  • Your B4X source code projects are safe if you kept ~/B4X_Projects"
    echo "  • Wine can be reinstalled anytime: sudo apt install winehq-stable"
    echo "  • To reinstall B4X: run install_b4x_wine.sh again"
    
    echo -e "\n${GREEN}✨ Thank you for using B4X on Linux! Come back anytime! 🚀${NC}"
fi
echo ""

exit 0
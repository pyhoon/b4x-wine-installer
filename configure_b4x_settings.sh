#!/bin/bash
#===============================================================================
# B4X Unified Post-Install Configuration Script
# Configures b4xV5.ini for B4A and/or B4J with optimized settings
# Author: pyhoon (Aeric) | AI Assistant: Qwen3.6 Plus
# Date: 03 June 2026
# License: MIT
#===============================================================================
set -euo pipefail

#-------------------------------------------------------------------------------
# CONFIGURATION
#-------------------------------------------------------------------------------
WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
B4X_PROJECTS_DIR="B4X_Projects"
# Paths use single backslashes. ini_set() handles sed escaping automatically.
B4X_PROJECTS_PATH="Z:\home\\$(whoami)\\${B4X_PROJECTS_DIR}"
B4X_ADDITIONAL_LIBRARIES="C:\Additional Libraries"
JAVA_BIN_PATH="C:\Java\jdk-19.0.2\bin"
ANDROID_SDK_PLATFORM="C:\Android\platforms\android-36"

# INI file locations (created by IDEs on first launch)
B4A_INI_FILE="${WINE_PREFIX}/drive_c/users/$(whoami)/AppData/Roaming/Anywhere Software/Basic4android/b4xV5.ini"
B4J_INI_FILE="${WINE_PREFIX}/drive_c/users/$(whoami)/AppData/Roaming/Anywhere Software/B4J/b4xV5.ini"

# Colors
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

log_info()    { echo -e "${YELLOW}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }

#-------------------------------------------------------------------------------
# ROBUST INI FILE HELPER
#-------------------------------------------------------------------------------
prepare_ini() {
    local file="$1"
    [[ ! -f "$file" ]] && return 1
    # Strip UTF-8 BOM & normalize Windows line endings (\r\n -> \n)
    sed -i '1s/^\xEF\xBB\xBF//' "$file" 2>/dev/null || true
    sed -i 's/\r$//' "$file" 2>/dev/null || true
}

ini_set() {
    local file="$1" key="$2" value="$3"
    prepare_ini "$file" || return 1
    
    # Escape backslashes for sed replacement (\ -> \\)
    local escaped_value="${value//\\/\\\\}"
    
    # Flexible match: handles optional spaces around '='
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file" 2>/dev/null; then
        sed -i "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${escaped_value}|" "$file"
    else
        # Append new key (uses original single-backslash value)
        echo "${key}=${value}" >> "$file"
    fi
}

#-------------------------------------------------------------------------------
# SELECTION LOGIC (CLI + Interactive Menu)
#-------------------------------------------------------------------------------
DO_B4A=false
DO_B4J=false

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --b4a) DO_B4A=true; shift ;;
            --b4j) DO_B4J=true; shift ;;
            --all) DO_B4A=true; DO_B4J=true; shift ;;
            -h|--help) 
                echo "Usage: $0 [--b4a|--b4j|--all]"
                echo "  --b4a  Configure B4A only"
                echo "  --b4j  Configure B4J only"
                echo "  --all  Configure both B4A & B4J"
                exit 0 ;;
            *) log_error "Unknown option: $1"; exit 1 ;;
        esac
    done
}

select_products() {
    # If flags weren't set via CLI, show interactive menu
    if [[ "$DO_B4A" == false && "$DO_B4J" == false ]]; then
        echo -e "\n${YELLOW}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  Select Product(s) to Configure                        ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════╝${NC}\n"

        PS3="Enter choice: "
        options=("B4A Only" "B4J Only" "Both B4A & B4J" "Quit")
        select opt in "${options[@]}"; do
            case $opt in
                "B4A Only") DO_B4A=true; break ;;
                "B4J Only") DO_B4J=true; break ;;
                "Both B4A & B4J") DO_B4A=true; DO_B4J=true; break ;;
                "Quit") log_info "Configuration cancelled."; exit 0 ;;
                *) log_warn "Invalid choice. Try again." ;;
            esac
        done
        
        if [[ "$DO_B4A" == false && "$DO_B4J" == false ]]; then
            log_error "No product selected."
            exit 1
        fi
    fi
}

#-------------------------------------------------------------------------------
# CONFIGURATION APPLIER
#-------------------------------------------------------------------------------
configure_product() {
    local product="$1" ini_file="$2"
    echo -e "\n${GREEN}▶ Configuring ${product}...${NC}"
    
    if [[ ! -f "$ini_file" ]]; then
        log_error "b4xV5.ini not found for ${product}: ${ini_file}"
        log_info "Please launch ${product} at least once first, then run this script again."
        return 1
    fi

    # Apply shared settings
    ini_set "$ini_file" "AdditionalLibrariesFolder" "${B4X_ADDITIONAL_LIBRARIES}"
    ini_set "$ini_file" "FontName2" "Ubuntu Sans Mono"
    ini_set "$ini_file" "FontSize2" "15"
    ini_set "$ini_file" "logs_FontName2" "Ubuntu Sans"
    ini_set "$ini_file" "logs_FontSize2" "15"
    ini_set "$ini_file" "JavaBin" "${JAVA_BIN_PATH}"
    ini_set "$ini_file" "NewProjectDefaultFolder" "${B4X_PROJECTS_PATH}"
    
    # B4A-specific setting
    [[ "$product" == "B4A" ]] && ini_set "$ini_file" "PlatformFolder" "${ANDROID_SDK_PLATFORM}"
    
    log_success "${product} configuration applied!"
    return 0
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
parse_args "$@"
select_products

echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  B4X Post-Install Configuration${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}\n"

B4A_OK=true
B4J_OK=true

[[ "$DO_B4A" == true ]] && configure_product "B4A" "$B4A_INI_FILE" || B4A_OK=false
[[ "$DO_B4J" == true ]] && configure_product "B4J" "$B4J_INI_FILE" || B4J_OK=false

# Handle partial failures gracefully
if [[ "$DO_B4A" == true && "$B4A_OK" == false || "$DO_B4J" == true && "$B4J_OK" == false ]]; then
    echo -e "\n${RED}⚠️ Some configurations failed. Check the errors above.${NC}\n"
    exit 1
fi

echo -e "\n${YELLOW}✅ Applied settings:${NC}"
if [[ "$DO_B4A" == true && -f "$B4A_INI_FILE" ]]; then
    grep -E "^(AdditionalLibrariesFolder|FontName2|FontSize2|JavaBin|logs_FontName2|logs_FontSize2|NewProjectDefaultFolder|PlatformFolder)=" "$B4A_INI_FILE" | sed 's/^/  • [B4A] /'
fi
if [[ "$DO_B4J" == true && -f "$B4J_INI_FILE" ]]; then
    grep -E "^(AdditionalLibrariesFolder|FontName2|FontSize2|JavaBin|logs_FontName2|logs_FontSize2|NewProjectDefaultFolder)=" "$B4J_INI_FILE" | sed 's/^/  • [B4J] /'
fi

echo -e "\n${GREEN}✨ Configuration complete! Launch B4X IDEs to enjoy your optimized settings.${NC}\n"
exit 0

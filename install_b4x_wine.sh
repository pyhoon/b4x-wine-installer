#!/bin/bash
#===============================================================================
# B4X Unified Silent Installer for Linux (Wine-based)
# Supports: B4A, B4J, or Both in a single Wine prefix.
# Distros:  Ubuntu/Mint/Debian-based and Arch-based (Manjaro, EndeavourOS,
#           Garuda, CachyOS, Artix, ...)
# Author: pyhoon (Aeric) | AI Assistant: Qwen3.6 Plus
# Date: 28 May 2026  (Updated 06 June 2026)
# License: MIT
#===============================================================================
set -e  # Exit on error

#-------------------------------------------------------------------------------
# 🔧 CONFIGURABLE PATHS & SETTINGS
# Edit these values OR override via environment variables before running.
#-------------------------------------------------------------------------------
WINE_PREFIX="${WINE_PREFIX:-${HOME}/.wine_b4x}"
WINE_ARCH="win64"
JAVA_WINE_PATH="C:\\Java"
JDK_URL="https://www.b4x.com/b4j/files/jdk-19.0.2.zip"

# B4A Specific
B4A_URL="https://www.b4x.com/android/files/B4A.exe"
SDK_CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-win-13114758_latest.zip"
SDK_RESOURCES_URL="https://github.com/AnywhereSoftware/B4A/releases/download/7_25/resources_7_25.zip"
SDK_WINE_PATH="C:\\Android"
SDK_LINUX_PATH="${WINE_PREFIX}/drive_c/Android"
B4A_INSTALL_DIR="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4A"

# B4J Specific
B4J_URL="https://www.b4x.com/b4j/files/B4J.exe"
B4J_INSTALL_DIR="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4J"

# Shared Folders
ADDITIONAL_LIBS_DIR="${WINE_PREFIX}/drive_c/Additional Libraries"

# Projects Directories
B4X_PROJECTS_DIR="${B4X_PROJECTS_DIR:-${HOME}/B4X_Projects}"

# Desktop Entries & Icons
B4A_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4a.desktop"
B4J_DESKTOP_ENTRY="${HOME}/.local/share/applications/b4j.desktop"
B4A_ICON_URL="https://raw.githubusercontent.com/pyhoon/b4x-wine-installer/refs/heads/main/icons/B4A.png"
B4J_ICON_URL="https://raw.githubusercontent.com/pyhoon/b4x-wine-installer/refs/heads/main/icons/B4J.png"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Installation Flags (set by CLI or menu)
INSTALL_B4A=false
INSTALL_B4J=false

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
log_error()   { echo -e "${RED}[✗]${NC} $1" >&2; exit 1; }

check_root() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do not run this script as root. Use sudo only when prompted."
    fi
}

# Detected distribution family. Populated by detect_distro().
#   "arch"   -> pacman-based (Arch, Manjaro, EndeavourOS, Garuda, CachyOS, Artix...)
#   "ubuntu" -> apt-based    (Linux Mint, Ubuntu, Pop!_OS, Debian derivatives...)
DISTRO=""
OS_ID=""
OS_ID_LIKE=""
OS_PRETTY_NAME=""

detect_distro() {
    [[ -f /etc/os-release ]] || log_error "Cannot detect OS: /etc/os-release not found"
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="${ID:-}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_PRETTY_NAME="${PRETTY_NAME:-${OS_ID:-unknown}}"

    # Arch and its derivatives (by ID)
    case "$OS_ID" in
        arch|manjaro|garuda|endeavouros|cachyos|artix)
            DISTRO="arch"; return ;;
    esac
    # Arch derivatives via ID_LIKE
    case " ${OS_ID_LIKE} " in
        *\ arch\ *)
            DISTRO="arch"; return ;;
    esac
    # Debian/Ubuntu/Mint family (by ID)
    case "$OS_ID" in
        linuxmint|ubuntu|debian|pop|neon)
            DISTRO="ubuntu"; return ;;
    esac
    # Debian/Ubuntu/Mint family (via ID_LIKE)
    case " ${OS_ID_LIKE} " in
        *\ debian\ *|*\ ubuntu\ *|*\ mint\ *)
            DISTRO="ubuntu"; return ;;
    esac
    log_error "Unsupported distribution: ID='${OS_ID}' ID_LIKE='${OS_ID_LIKE}'. Supported: Arch-based or Ubuntu/Mint/Debian-based."
}

check_supported() {
    detect_distro
    log_info "Detected distribution: ${OS_PRETTY_NAME} (${DISTRO}-based)"
}

get_ubuntu_codename() {
    local codename
    codename=$(grep '^UBUNTU_CODENAME=' /etc/os-release | cut -d= -f2)
    case "$codename" in
        noble|jammy) echo "$codename" ;;
        *) log_error "Unsupported Ubuntu base: $codename (Mint 21.x=jammy, 22.x=noble)" ;;
    esac
}

download_file() {
    local url="$1" dest="$2"
    if command -v wget &>/dev/null; then
        wget -q --show-progress -O "$dest" "$url"
    elif command -v curl &>/dev/null; then
        curl -fSL -o "$dest" "$url"
    else
        log_error "Neither wget nor curl found. Please install one."
    fi
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --b4a      Install B4A only"
    echo "  --b4j      Install B4J only"
    echo "  --all      Install both B4A & B4J"
    echo "  -h, --help Show this help message"
    exit 0
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --b4a) INSTALL_B4A=true; shift ;;
            --b4j) INSTALL_B4J=true; shift ;;
            --all) INSTALL_B4A=true; INSTALL_B4J=true; shift ;;
            -h|--help) show_help ;;
            *) log_error "Unknown option: $1"; show_help ;;
        esac
    done
}

select_products() {
    # If flags weren't set via CLI, show interactive menu
    if [[ "$INSTALL_B4A" == false && "$INSTALL_B4J" == false ]]; then
        echo -e "Select B4X Product(s) to Install:"
        
        PS3="Enter choice: "
        options=("B4A Only" "B4J Only" "Both B4A & B4J" "Quit")
        select opt in "${options[@]}"; do
            case $opt in
                "B4A Only") INSTALL_B4A=true; break ;;
                "B4J Only") INSTALL_B4J=true; break ;;
                "Both B4A & B4J") INSTALL_B4A=true; INSTALL_B4J=true; break ;;
                "Quit") log_info "Installation cancelled."; exit 0 ;;
                *) log_warn "Invalid choice. Try again." ;;
            esac
        done
        
        if [[ "$INSTALL_B4A" == false && "$INSTALL_B4J" == false ]]; then
            log_error "No product selected."
        fi
    fi
}

#-------------------------------------------------------------------------------
# MAIN INSTALLATION STEPS
#-------------------------------------------------------------------------------
echo -e "\n"
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  B4X Unified Installer for Linux                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}\n"

check_root
check_supported
parse_args "$@"
select_products

log_info "Configuration:"
[[ "$INSTALL_B4A" == true ]] && echo -e "  ${GREEN}• B4A: Enabled${NC}"
[[ "$INSTALL_B4J" == true ]] && echo -e "  ${GREEN}• B4J: Enabled${NC}"
echo -e "  ${YELLOW}• Wine Prefix: ${WINE_PREFIX}${NC}"
echo -e "  ${YELLOW}• Java Path: ${JAVA_WINE_PATH}${NC}"
[[ "$INSTALL_B4A" == true ]] && echo -e "  ${YELLOW}• Android SDK: ${SDK_WINE_PATH}${NC}"
echo -e "  ${YELLOW}• B4X Projects: ${B4X_PROJECTS_DIR}${NC}"
echo ""

#-------------------------------------------------------------------------------
# 1. System & Wine Setup (Distribution-aware)
#-------------------------------------------------------------------------------
install_wine_ubuntu() {
    log_info "Enabling 32-bit architecture support..."
    sudo dpkg --add-architecture i386 2>/dev/null || true

    log_info "Cleaning up any conflicting WineHQ repository configurations..."
    sudo rm -f /etc/apt/sources.list.d/winehq*.sources /etc/apt/sources.list.d/winehq*.list /etc/apt/sources.list.d/winehq*.list.save 2>/dev/null || true
    sudo rm -f /usr/share/keyrings/winehq*.gpg /etc/apt/keyrings/winehq*.key 2>/dev/null || true
    sudo apt clean -qq 2>/dev/null || true

    log_info "Adding fresh WineHQ repository..."
    CODENAME=$(get_ubuntu_codename)
    sudo install -m 0755 -d /usr/share/keyrings
    curl -fsSL https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/winehq.gpg
    sudo tee /etc/apt/sources.list.d/winehq.sources > /dev/null <<EOF
Types: deb
URIs: https://dl.winehq.org/wine-builds/ubuntu/
Suites: ${CODENAME}
Components: main
Signed-By: /usr/share/keyrings/winehq.gpg
EOF
    sudo apt update -qq

    log_info "Installing Wine Stable & Winetricks (apt)..."
    sudo apt install -y --install-recommends winehq-stable winetricks cabextract unzip
}

ensure_multilib_arch() {
    # 32-bit Wine on Arch requires the [multilib] repository.
    if sudo grep -qE '^\[multilib\]' /etc/pacman.conf; then
        log_info "[multilib] repository already enabled"
        return 0
    fi

    log_info "Enabling [multilib] repository in /etc/pacman.conf..."
    sudo cp /etc/pacman.conf "/etc/pacman.conf.bak.$(date +%Y%m%d%H%M%S)"

    if sudo grep -qE '^#\[multilib\]' /etc/pacman.conf; then
        # Uncomment the existing commented [multilib] block (and its Include line).
        # State-aware: only affects lines inside the [multilib] section.
        local tmp; tmp=$(mktemp) || log_error "Failed to create temp file"
        sudo awk '
            /^#\[multilib\]/    { in_ml=1; sub(/^#/, ""); print; next }
            /^\[[^#]/           { in_ml=0 }
            in_ml && /^#/       { sub(/^#/, ""); print; next }
            { print }
        ' /etc/pacman.conf > "$tmp"
        sudo install -m 644 "$tmp" /etc/pacman.conf
        rm -f "$tmp"
    else
        # No commented block exists: append a fresh section at the end.
        printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' \
            | sudo tee -a /etc/pacman.conf > /dev/null
    fi
    log_success "[multilib] repository enabled (backup saved as /etc/pacman.conf.bak.*)"
}

install_wine_arch() {
    ensure_multilib_arch

    # Paquetes auxiliares (siempre necesarios). `--needed` de pacman ya salta
    # los que estén instalados, sin riesgo de conflicto.
    local pkgs=(
        winetricks
        cabextract
        unzip
        wget
        curl
        desktop-file-utils
    )

    # wine / wine-staging / wine-git / proton-wine / wine-wow64 / ...
    # son proveedores mutuamente excluyentes del binario `wine`. Si el
    # usuario ya tiene cualquiera de ellos, lo respetamos y NO pedimos el
    # paquete `wine` (que de lo contrario entraría en conflicto).
    if command -v wine >/dev/null 2>&1; then
        local current; current=$(wine --version 2>/dev/null || echo "unknown")
        log_info "Wine ya instalado (${current}) — se respeta; no se instalará el paquete 'wine'"
    else
        pkgs+=(wine wine-gecko wine-mono)
    fi

    log_info "Instalando dependencias (pacman): ${pkgs[*]}"
    sudo pacman -Sy --needed --noconfirm "${pkgs[@]}" \
        || log_error "Failed to install packages via pacman"
}

install_wine() {
    case "$DISTRO" in
        arch)   install_wine_arch ;;
        ubuntu) install_wine_ubuntu ;;
        *)      log_error "Unknown DISTRO: $DISTRO" ;;
    esac
    WINE_VERSION=$(wine --version 2>/dev/null || echo "unknown")
    log_success "Wine installed: ${WINE_VERSION}"
}

install_wine

#-------------------------------------------------------------------------------
# 2. Create & Configure Wine Prefix (Shared)
#-------------------------------------------------------------------------------
export WINEARCH="${WINE_ARCH}"
export WINEPREFIX="${WINE_PREFIX}"
log_info "Creating/Updating 64-bit Wine prefix: ${WINE_PREFIX}..."
wineboot -u 2>/dev/null || true

log_info "Installing shared dependencies (VC++ 2010, .NET 4.5.2, DXVK, GDI)..."
winetricks -q vcrun2010 dotnet452 dxvk renderer=gdi 2>/dev/null || log_warn "Some dependencies failed. B4X may still work."
winecfg -v win10 2>/dev/null || true

#-------------------------------------------------------------------------------
# 3. Install JDK 19 (Shared)
#-------------------------------------------------------------------------------
log_info "Downloading & extracting JDK 19 to C:\\Java..."
mkdir -p "${WINE_PREFIX}/drive_c/Java"
JDK_ZIP="${WINE_PREFIX}/drive_c/temp/jdk-19.0.2.zip"
mkdir -p "$(dirname "$JDK_ZIP")"
download_file "${JDK_URL}" "$JDK_ZIP"

JDK_EXTRACT_DIR="${WINE_PREFIX}/drive_c/temp/jdk_extract"
mkdir -p "$JDK_EXTRACT_DIR"
unzip -q "$JDK_ZIP" -d "$JDK_EXTRACT_DIR"
JDK_SRC=$(find "$JDK_EXTRACT_DIR" -maxdepth 1 -type d -name "jdk*" | head -1)
if [[ -n "$JDK_SRC" && -d "$JDK_SRC" ]]; then
    cp -r "$JDK_SRC"/* "${WINE_PREFIX}/drive_c/Java/"
    log_success "JDK 19 installed to C:\\Java"
else
    log_warn "Could not locate JDK folder in archive"
fi
rm -rf "$JDK_EXTRACT_DIR" "$JDK_ZIP"

#-------------------------------------------------------------------------------
# 4. B4A Installation (Conditional)
#-------------------------------------------------------------------------------
if [[ "$INSTALL_B4A" == true ]]; then
    log_info ">>> Installing B4A..."
    B4A_INSTALLER="${WINE_PREFIX}/drive_c/temp/B4A.exe"
    mkdir -p "$(dirname "$B4A_INSTALLER")"
    download_file "${B4A_URL}" "$B4A_INSTALLER"
    wine "$B4A_INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART 2>/dev/null || wine "$B4A_INSTALLER" 2>/dev/null || log_warn "B4A installation failed"

    # Android SDK
    log_info "Setting up Android SDK..."
    SDK_ZIP="${WINE_PREFIX}/drive_c/temp/commandlinetools.zip"
    mkdir -p "$(dirname "$SDK_ZIP")"
    download_file "${SDK_CMDLINE_URL}" "$SDK_ZIP"
    
    SDK_TARGET="${SDK_LINUX_PATH}/cmdline-tools"

    # ✅ FIX: Skip if already installed to avoid 'Directory not empty' error
    if [[ -d "$SDK_TARGET" && -f "${SDK_TARGET}/bin/sdkmanager.bat" ]]; then
        log_info "Android SDK Command Line Tools already installed. Skipping."
    else
        # Create parent dir only (NOT the target, so mv can create it cleanly)
        mkdir -p "$(dirname "$SDK_TARGET")"
        
        SDK_TEMP="${WINE_PREFIX}/drive_c/temp/sdk_extract"
        rm -rf "$SDK_TEMP" 2>/dev/null || true
        unzip -q "$SDK_ZIP" -d "$SDK_TEMP"
        
        if [[ -d "${SDK_TEMP}/cmdline-tools" ]]; then
            mv "${SDK_TEMP}/cmdline-tools" "$SDK_LINUX_PATH"
            log_success "Android SDK Command Line Tools extracted to ${SDK_WINE_PATH}"
        else
            log_warn "Unexpected SDK archive structure. Fallback extraction skipped."
        fi
        rm -rf "$SDK_TEMP" "$SDK_ZIP"
    fi

    # Licenses & Resources
    mkdir -p "${SDK_LINUX_PATH}/licenses"
    echo "24333f8a63b6825ea9c5514f83c2829b004d1fee" > "${SDK_LINUX_PATH}/licenses/android-sdk-license"
    echo "84831b9409646a918e30573bab4c9c91346d8abd" > "${SDK_LINUX_PATH}/licenses/android-sdk-preview-license"
    
    RES_ZIP="${WINE_PREFIX}/drive_c/temp/resources_7_25.zip"
    download_file "${SDK_RESOURCES_URL}" "$RES_ZIP"
    unzip -q -o "$RES_ZIP" -d "$SDK_LINUX_PATH" 2>/dev/null || true
    rm -f "$RES_ZIP"

    # Launcher
    B4A_EXE="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4A/B4A.exe"
    [[ ! -f "$B4A_EXE" ]] && B4A_EXE="${WINE_PREFIX}/drive_c/Program Files (x86)/Anywhere Software/B4A/B4A.exe"
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
fi

#-------------------------------------------------------------------------------
# 5. B4J Installation (Conditional)
#-------------------------------------------------------------------------------
if [[ "$INSTALL_B4J" == true ]]; then
    log_info ">>> Installing B4J..."
    B4J_INSTALLER="${WINE_PREFIX}/drive_c/temp/B4J.exe"
    mkdir -p "$(dirname "$B4J_INSTALLER")"
    download_file "${B4J_URL}" "$B4J_INSTALLER"
    wine "$B4J_INSTALLER" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART 2>/dev/null || wine "$B4J_INSTALLER" 2>/dev/null || log_warn "B4J installation failed"

    # Launcher
    B4J_EXE="${WINE_PREFIX}/drive_c/Program Files/Anywhere Software/B4J/B4J.exe"
    [[ ! -f "$B4J_EXE" ]] && B4J_EXE="${WINE_PREFIX}/drive_c/Program Files (x86)/Anywhere Software/B4J/B4J.exe"
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
fi

#-------------------------------------------------------------------------------
# 6. Shared Folders & Permissions
#-------------------------------------------------------------------------------
log_info "Creating Additional Libraries folders..."
mkdir -p "${ADDITIONAL_LIBS_DIR}/B4A" "${ADDITIONAL_LIBS_DIR}/B4J" "${ADDITIONAL_LIBS_DIR}/B4X"

log_info "Creating B4X Projects folder..."
mkdir -p "$B4X_PROJECTS_DIR"

log_info "Setting permissions..."
chmod -R u+rwX "${WINE_PREFIX}" 2>/dev/null || true
chmod -R u+rwX "$B4X_PROJECTS_DIR" 2>/dev/null || true

#-------------------------------------------------------------------------------
# 7. Final Messages
#-------------------------------------------------------------------------------
echo -e "\n${GREEN}════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  ✓ B4X Installation Complete!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════${NC}\n"

echo -e "${YELLOW}📋 Installed Products:${NC}"
[[ "$INSTALL_B4A" == true ]] && echo "  • B4A (Android Development)"
[[ "$INSTALL_B4J" == true ]] && echo "  • B4J (Desktop/Web Development)"

echo -e "\n${YELLOW}⚙️  Configuration Summary:${NC}"
echo "  • Wine Prefix: ${WINE_PREFIX}"
echo "  • Java Path: C:\\Java (JDK 19)"
[[ "$INSTALL_B4A" == true ]] && echo "  • Android SDK: C:\\Android"
echo "  • B4X Projects: ${B4X_PROJECTS_DIR}"
echo "  • Additional Libraries: C:\\Additional Libraries\\{B4A,B4J,B4X}"

echo -e "\n${YELLOW}🚀 Next Steps:${NC}"
echo "  1. Launch B4A/B4J from your Desktop shortcut or Application Menu."
echo "  2. Open menu Tools → Configure Paths."
echo "  3. Set javac.exe to C:\Java\jdk-19.0.2\bin\javac.exe"
echo "  4. For B4A, set android.jar to C:\Android\platforms\android-36\android.jar"
echo "  5. (Optional) Set Additional Libraries path to C:\Additional Libraries"
echo "  Alternatively: Run ./configure_b4x_settings.sh to set recommended settings."

echo -e "\n${GREEN}Happy B4X development on Linux! 🤖🐧☕${NC}\n"
exit 0
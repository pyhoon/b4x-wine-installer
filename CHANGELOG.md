# Changelog

All notable changes are documented here. Previous update: **17 Jun 2026** (`c510ef8`). This file covers **22 Sep 2026 – Oct 2026** (`8fc369a` … `a88217c`, plus uncommitted Wayland support).

Diff vs previous update: `install_b4x_wine.sh` +274/−108, `README.md` +32/−5.

## 22 Sep 2026 — Reinstall options, WineHQ repo hardening, B4A completion fix

Commits: `8fc369a`, `a73073d`, `f7b330c`, `ffa2cd4`, `f7cb86e`, `6b577d4`

### Added
- **Reinstall options** — reinstall only the IDE(s) you choose without touching shared dependencies (Wine, Winetricks components, JDK 19, Android SDK):
  - CLI flags: `--reinstall-b4a`, `--reinstall-b4j`, `--reinstall-all`
  - Matching interactive menu entries: *Reinstall B4A Only*, *Reinstall B4J Only*, *Reinstall B4A & B4J*
  - Reinstall mode verifies Wine is present, creates the prefix only if missing, and still recreates desktop launchers.
- Configuration output now shows `Mode: Install` or `Mode: Reinstall`, and the completion summary notes when dependencies were skipped.

### Fixed
- **WineHQ apt source no longer corrupted on Linux Mint** — the root cause of `E: Malformed entry 1 in sources file .../winehq.sources (Component)`:
  - `get_ubuntu_codename()` now prefers `UBUNTU_CODENAME` from `/etc/os-release` (Mint's `lsb_release -sc` returns the Mint codename, e.g. `wilma`, which WineHQ doesn't use); `WINE_REPO_CODENAME` override is respected as-is.
  - All `log_info`/`log_warn`/`log_success` output goes to **stderr**, so warning text can never be captured into `CODENAME=$(...)` and written into the sources file.
  - Codename is stripped of CR/whitespace and validated (`^[a-z0-9]+$`); invalid values abort with a clear message.
  - Generated `winehq.sources` is validated (Types/Suites/Components) **before** apt reads it; on validation or `apt update` failure the file is removed automatically so system apt is never left broken.
- **B4A-only install no longer aborts silently** — `download_file` failures now print `[!] Download failed: <url>` and remove the partial file (previously `wget -q` failed silently under `set -e`, killing the script before the desktop launcher was created).
- **B4X resources step is non-fatal** — download/extract failure only warns; B4A installs and the launcher is created regardless.
- **Silent `unzip` exits** for the JDK and Android command-line tools now report a clear error instead of ending the script with no output.

### Changed
- Existing `B4A.exe` / `B4J.exe` in `drive_c/temp` are **removed before every download** to guarantee a fresh installer.
- Android `commandlinetools` zip (~136 MB) is downloaded **only when SDK tools are actually missing** — no re-download on every run and no leftover zip in temp on the skip path.
- Added an "Extracting B4X resources…" progress message (extraction previously looked like a hang due to `unzip -q`).
- Script header credits updated (Qwen3.6 Plus + MiMo-V2.6-Flash Free) and date bumped to 22 Sep 2026.

### Docs
- README documents the reinstall flags (features list + usage examples) and the "Last updated" footer is refreshed to 22 Sep 2026.

## Oct 2026 — Vulkan auto-detection, Wayland support, launcher fixes

Commits: `90d72ac`, `c4699ad`, `4778e25`, `8c87264`, `a88217c` (PR #4) + uncommitted Wayland changes.

### Added
- **Wayland / X11-free support** (`B4X_GRAPHICS=auto|xwayland|wayland`, default `auto`):
  - Auto-detects a working X display (X11/XWayland) and prefers the proven `x11` driver; otherwise falls back to Wine's native **Wayland** driver when `WAYLAND_DISPLAY` is present.
  - The chosen driver is stored in the Wine prefix (`HKCU\Software\Wine\Drivers` → `Graphics`) for both install and reinstall modes.
  - Warns and falls back to X11 when the Wine build is older than 9 (no native Wayland driver).
  - Configuration summary now shows the selected graphics driver.
- **Vulkan auto-detection** (contributor PR #4): detects Vulkan 1.3+ via `vulkaninfo` and installs DXVK; otherwise forces the wined3d OpenGL fallback (`d3d9`/`d3d11`/`dxgi` builtin) plus `fontsmooth=rgb`/`corefonts`.

### Fixed
- **Desktop launchers**: `Path=` now uses the detected install directory (`dirname` of `B4A.exe`/`B4J.exe`), so "open folder"-style actions work with 32-bit (`Program Files (x86)`) installs.

### Docs
- README: new **Desktop / Display Server Support** table (Mint 22.x / Ubuntu 24.04 recommended; Ubuntu 26.04 via XWayland; Wayland-only experimental), `B4X_GRAPHICS` usage, and a recommendation to avoid interim Ubuntu releases (24.10–25.10).
- README: B4A startup/Vulkan troubleshooting revised (PR #4); screenshot assets renamed to `screenshots/01.png` … `04.png`.
- README "Last updated" footer (and script header date) bumped to 26 Oct 2026, noting Wayland compatibility.

---

*Verified: `bash -n` clean, codename tests 6/6, `download_file` tests 7/7, graphics-mode tests 7/7, `--help` OK.*

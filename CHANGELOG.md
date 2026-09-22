# Changelog

All notable changes are documented here. The previous update was **17 Jun 2026** (`c510ef8`); everything below covers **22 Sep 2026** (`8fc369a` … `6b577d4`).

## 22 Sep 2026 — Reinstall options, WineHQ repo hardening, B4A completion fix

Commits: `8fc369a`, `a73073d`, `f7b330c`, `ffa2cd4`, `f7cb86e`, `6b577d4`
Diff vs previous update: `install_b4x_wine.sh` +196/−106, `README.md` +8/−2 (204 insertions, 108 deletions)

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

---

*Verified: `bash -n` clean, 6/6 codename unit tests, 7/7 `download_file` unit tests, `--help` OK. Remote `main` confirmed at `6b577d4`.*

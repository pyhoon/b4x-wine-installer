# Fedora / Red Hat-based distributions

This directory contains an installer entry point for Fedora and compatible
distributions such as RHEL, Rocky Linux, AlmaLinux, and CentOS Stream.

Run it from a checkout of this repository:

```bash
chmod +x other-distros/fedora/install_b4x_wine.sh
./other-distros/fedora/install_b4x_wine.sh --all
```

You can also use `--b4a` or `--b4j`, or omit the option for the interactive
product selection. The script installs Wine, Winetricks, extraction/download
tools, and available 32-bit Wine libraries with `dnf` before launching the
shared B4X installation flow.

Some RHEL-compatible systems may not provide Winetricks or Wine's 32-bit
libraries in their enabled repositories. Enable the appropriate repositories
for your release (for example, EPEL where applicable) before running the
installer if `dnf` cannot find those packages.

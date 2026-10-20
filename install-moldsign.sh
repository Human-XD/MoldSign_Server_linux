#!/usr/bin/env bash
# MoldSign for Ubuntu/Debian with Moldovan eID card (buletin cu cip) support.
#
# The official Linux MoldSign (semnatura.md) only ships USB-token drivers
# (ePass2003, SafeNet), so the eID card shows "Nu s-a găsit niciun certificat".
# This script installs MoldSign per-user in ~/MoldSign and adds the official
# Bit4id Universal Middleware (PKCS#11) driver, which reads the eID card.
#
# Usage (run as your normal user, NOT with sudo):
#   bash install-moldsign.sh              install / reinstall
#   bash install-moldsign.sh --uninstall  remove MoldSign from this user
#
# Optional environment variables:
#   MOLDSIGN_TAR=/path/MoldSign_Install.tar.xz   use a local copy instead of downloading
#   BIT4ID_ZIP=/path/Bit4id_Middleware.zip       use a local copy instead of downloading
#   ALLOW_UNVERIFIED=1   accept downloads whose checksum changed (newer upstream release)
#   INSTALL_DIR=...      install location (default: ~/MoldSign)
#   NO_SYSTEM=1          skip apt/pcscd step (packages already installed)
#   NO_DESKTOP=1         skip menu/autostart entries and don't start the server

set -euo pipefail

MOLDSIGN_URL="https://semnatura.md/instalare/Dist/MoldSign_Install.tar.xz"
MOLDSIGN_SHA256="c39ff68f736b8e619b2715f2de8a221de55a0341c24a7a6af6f21ea6fa58e209"  # v2.4.12, 2025-07-11
BIT4ID_URL="https://cdn.bit4id.com/es/soporte/downloads/middleware/Bit4id_Middleware.zip"
BIT4ID_SHA256="0f6d45d1f7d550f9188404feb23f977b8b19b4b7f5475eef8fc79647d9be9ff5"    # 1.4.11.836

INSTALL_DIR="${INSTALL_DIR:-$HOME/MoldSign}"
APPS_DIR="$HOME/.local/share/applications"
AUTOSTART_DIR="$HOME/.config/autostart"

say()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!! \033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mXX \033[0m %s\n' "$*" >&2; exit 1; }

stop_server() {
    pkill -f "MoldSignClientCardManagement-2.0.jar" 2>/dev/null || true
    pkill -f "ClientCardServer-2.0.jar" 2>/dev/null || true
    sleep 2
}

uninstall() {
    say "Stopping MoldSign"
    stop_server
    rm -f "$APPS_DIR/moldsign-server.desktop" "$APPS_DIR/moldsign-desk.desktop" \
          "$AUTOSTART_DIR/moldsign-server.desktop"
    if [ -d "$INSTALL_DIR" ]; then
        say "Removing $INSTALL_DIR"
        rm -rf "$INSTALL_DIR"
    fi
    say "MoldSign removed. (System packages pcscd/libccid were left installed.)"
}

fetch() {  # fetch <url> <dest> <sha256> <local-override>
    local url="$1" dest="$2" sum="$3" local_copy="$4"
    if [ -n "$local_copy" ]; then
        [ -f "$local_copy" ] || die "File not found: $local_copy"
        cp "$local_copy" "$dest"
    else
        say "Downloading $url"
        curl -fL --retry 3 --progress-bar -o "$dest" "$url" || die "Download failed: $url"
    fi
    local got
    got="$(sha256sum "$dest" | cut -d' ' -f1)"
    if [ "$got" != "$sum" ]; then
        if [ "${ALLOW_UNVERIFIED:-0}" = "1" ]; then
            warn "Checksum changed for $(basename "$dest") (upstream release changed?) - continuing (ALLOW_UNVERIFIED=1)"
        else
            die "Checksum mismatch for $(basename "$dest"): got $got
    Upstream may have published a new version. Re-run with ALLOW_UNVERIFIED=1 to accept it."
        fi
    fi
}

install_system_packages() {
    local pkgs=(pcscd libccid pcsc-tools zstd curl unzip)
    local missing=()
    for p in "${pkgs[@]}"; do
        dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q "install ok installed" || missing+=("$p")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        say "Installing system packages (needs your password): ${missing[*]}"
        sudo apt-get update
        sudo apt-get install -y "${missing[@]}"
    else
        say "System packages already installed"
    fi
    sudo systemctl enable --now pcscd.socket
    # Apply libccid's udev rules to a reader that was plugged in before installation
    sudo udevadm trigger --subsystem-match=usb --action=add || true
    if ! getent hosts localhost.cts.md >/dev/null; then
        say "Adding localhost.cts.md to /etc/hosts"
        echo "127.0.0.1 localhost.cts.md" | sudo tee -a /etc/hosts >/dev/null
    fi
}

write_desktop_entries() {
    mkdir -p "$APPS_DIR" "$AUTOSTART_DIR"
    cat > "$APPS_DIR/moldsign-server.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MoldSign Server
Comment=Local signing service for msign.gov.md
Exec=$INSTALL_DIR/MoldSign_Server.sh
Path=$INSTALL_DIR
Terminal=false
Categories=Utility;
X-GNOME-Autostart-enabled=true
EOF
    cat > "$APPS_DIR/moldsign-desk.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=MoldSign Desk
Comment=MoldSign card management
Exec=$INSTALL_DIR/MoldSign-Desk.sh
Path=$INSTALL_DIR
Terminal=false
Categories=Utility;
EOF
    cp "$APPS_DIR/moldsign-server.desktop" "$AUTOSTART_DIR/"
}

main() {
    [ "$(id -u)" -ne 0 ] || die "Run as your normal user, not root/sudo (MoldSign is installed per user)."
    [ "$(uname -m)" = "x86_64" ] || die "Only x86_64 is supported."
    command -v dpkg-deb >/dev/null || die "This script is for Ubuntu/Debian (dpkg-deb not found)."

    [ "${NO_SYSTEM:-0}" = "1" ] || install_system_packages

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "$TMP_DIR"' EXIT
    local tmp="$TMP_DIR"

    fetch "$MOLDSIGN_URL" "$tmp/moldsign.tar" "$MOLDSIGN_SHA256" "${MOLDSIGN_TAR:-}"
    fetch "$BIT4ID_URL" "$tmp/bit4id.zip" "$BIT4ID_SHA256" "${BIT4ID_ZIP:-}"

    say "Unpacking"
    mkdir -p "$tmp/ms" "$tmp/b4"
    # The upstream file is named .tar.xz but is actually zstd; let tar detect it.
    tar -xf "$tmp/moldsign.tar" -C "$tmp/ms"
    [ -f "$tmp/ms/MoldSign/MoldSign_Server.sh" ] || die "Unexpected MoldSign archive layout"
    unzip -q -o "$tmp/bit4id.zip" Bit4id_Middleware.deb -d "$tmp/b4"
    dpkg-deb -x "$tmp/b4/Bit4id_Middleware.deb" "$tmp/b4/root"
    local b4lib="$tmp/b4/root/usr/lib/bit4id"
    [ -f "$b4lib/libbit4xpki.so" ] || die "libbit4xpki.so not found in Bit4id package"

    if [ -d "$INSTALL_DIR" ]; then
        local backup="$INSTALL_DIR.bak-$(date +%Y%m%d-%H%M%S)"
        say "Existing install found - moving it to $backup"
        stop_server
        mv "$INSTALL_DIR" "$backup"
    fi
    mkdir -p "$(dirname "$INSTALL_DIR")"
    mv "$tmp/ms/MoldSign" "$INSTALL_DIR"

    say "Adding Bit4id eID driver"
    cp -a "$b4lib/libbit4xpki.so" "$b4lib/libbit4xpki.so.conf" "$b4lib/libbit4xpki.so.rc" \
          "$INSTALL_DIR/native_lib/"
    local props="$INSTALL_DIR/MoldSignData/Server/PKCS11.properties"
    [ -f "$props" ] || die "PKCS11.properties not found at $props"
    if ! grep -q '^driver_lib=.*libbit4xpki\.so' "$props"; then
        sed -i 's/^driver_lib=\(.*\)$/driver_lib=libbit4xpki.so|\1/' "$props"
    fi
    grep -q '^driver_lib=' "$props" || echo 'driver_lib=libbit4xpki.so|libcastle.1.0.0.so|libeToken.so' >> "$props"
    chmod +x "$INSTALL_DIR"/*.sh

    if [ "${NO_DESKTOP:-0}" != "1" ]; then
        say "Creating menu entries and autostart"
        write_desktop_entries
        say "Starting MoldSign Server"
        setsid -f "$INSTALL_DIR/MoldSign_Server.sh" >/dev/null 2>&1 </dev/null
    fi

    cat <<EOF

MoldSign installed in $INSTALL_DIR
  - It starts automatically at login ("MoldSign Server" in the app menu).
  - Insert the ID card in the reader. If the reader was already plugged in,
    unplug it and plug it back in once.
  - Check the reader:  pcsc_scan   (Ctrl+C to stop)
  - Server log:        $INSTALL_DIR/log/err_server.log
  - Then sign on https://msign.gov.md and choose MoldSign.
EOF
}

case "${1:-}" in
    --uninstall) uninstall ;;
    ""|--install) main ;;
    -h|--help) sed -n '2,22p' "$0" ;;
    *) die "Unknown option: $1 (use --help)" ;;
esac

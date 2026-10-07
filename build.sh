#!/usr/bin/env bash
# Bouwt de BearlyOS live-ISO met Debian live-build.
# Draai als root op Debian 12, of in een privileged debian:bookworm container.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

# shellcheck source=distro.conf
source ./distro.conf
DISTRO_VERSION="${DISTRO_VERSION:-dev}"

if [ "$(id -u)" -ne 0 ]; then
    echo "Dit script moet als root draaien (sudo ./build.sh)." >&2
    exit 1
fi

WORK="$ROOT/build"
OUT="$ROOT/out"

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"
cd "$WORK"

# ── live-build configureren ───────────────────────────────────────
lb config \
    --mode debian \
    --distribution "$DEBIAN_RELEASE" \
    --architectures amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --binary-images iso-hybrid \
    --debian-installer none \
    --firmware-binary true \
    --firmware-chroot true \
    --security true \
    --updates true \
    --backports false \
    --memtest none \
    --apt-recommends true \
    --image-name "$IMAGE_NAME" \
    --iso-application "$DISTRO_NAME" \
    --iso-publisher "$DISTRO_NAME" \
    --iso-volume "$ISO_VOLUME" \
    --bootappend-live "boot=live components quiet splash hostname=$LIVE_HOSTNAME username=$LIVE_USERNAME user-fullname=\"$LIVE_FULLNAME\" locales=$LIVE_LOCALE keyboard-layouts=$LIVE_KEYBOARD timezone=$LIVE_TIMEZONE"

# ── Eigen configuratie erover kopiëren (pakketlijsten, hooks, bestanden) ─
cp -a "$ROOT/config/." config/

# ── Merk-assets in de chroot plaatsen ─────────────────────────────
mkdir -p config/includes.chroot/usr/share/backgrounds/bearly \
         config/includes.chroot/usr/share/pixmaps
cp "$ROOT/assets/logo/wallpaper-dark.png" config/includes.chroot/usr/share/backgrounds/bearly/wallpaper-dark.png
cp "$ROOT/assets/logo/logo-light.png"     config/includes.chroot/usr/share/pixmaps/bearly-logo.png
cp "$ROOT/assets/logo/logo-icon-256.png"  config/includes.chroot/usr/share/pixmaps/bearly-icon.png

# Branding-waarden doorgeven aan de hooks in de chroot
mkdir -p config/includes.chroot/usr/share/distro
cat > config/includes.chroot/usr/share/distro/branding.conf <<EOF
DISTRO_NAME="$DISTRO_NAME"
DISTRO_VERSION="$DISTRO_VERSION"
LIVE_USERNAME="$LIVE_USERNAME"
EOF

# ── Bouwen ────────────────────────────────────────────────────────
lb build

ISO_SRC="$(ls -1 ./*.iso | head -n1)"
ISO_DST="$OUT/${IMAGE_NAME}-${DISTRO_VERSION}-amd64.iso"
mv "$ISO_SRC" "$ISO_DST"
(cd "$OUT" && sha256sum "$(basename "$ISO_DST")" > "$(basename "$ISO_DST").sha256")

echo "Klaar: $ISO_DST"
ls -lh "$OUT"

#!/usr/bin/env bash
# Bouwt de live-ISO met Debian live-build.
# Draai als root op Debian 12 (of in een privileged Debian-container),
# met het pakket "live-build" geïnstalleerd.
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
    --memtest none \
    --image-name "$IMAGE_NAME" \
    --iso-application "$DISTRO_NAME" \
    --iso-publisher "$DISTRO_NAME" \
    --iso-volume "$ISO_VOLUME" \
    --bootappend-live "boot=live components quiet splash hostname=$LIVE_HOSTNAME username=$LIVE_USERNAME locales=$LIVE_LOCALE keyboard-layouts=$LIVE_KEYBOARD timezone=$LIVE_TIMEZONE"

# Eigen aanpassingen (pakketlijsten, hooks, bestanden) erbovenop kopiëren
cp -a "$ROOT/config/." config/

# Branding-gegevens meegeven aan de chroot, zodat de hook ze kan lezen
mkdir -p config/includes.chroot/usr/share/distro
cat > config/includes.chroot/usr/share/distro/branding.conf <<EOF
DISTRO_NAME="$DISTRO_NAME"
DISTRO_VERSION="$DISTRO_VERSION"
EOF

lb build

ISO_SRC="$(ls -1 ./*.iso | head -n1)"
ISO_DST="$OUT/${IMAGE_NAME}-${DISTRO_VERSION}-amd64.iso"
mv "$ISO_SRC" "$ISO_DST"
(cd "$OUT" && sha256sum "$(basename "$ISO_DST")" > "$(basename "$ISO_DST").sha256")

echo "Klaar: $ISO_DST"
ls -lh "$OUT"

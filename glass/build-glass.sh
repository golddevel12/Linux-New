#!/usr/bin/env bash
# Bouwt de BearlyOS Glass live-ISO met archiso (Arch + Hyprland).
# Draai als root in een Arch-container met 'archiso' geïnstalleerd.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
VER="${DISTRO_VERSION:-dev}"

WORK="/tmp/glass-build"
PROFILE="$WORK/profile"
OUT="$REPO/out"

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"

# ── 1. Basisprofiel 'releng' kopiëren (boot/base al geregeld) ──
cp -r /usr/share/archiso/configs/releng "$PROFILE"

# ── 2. Desktop-pakketten toevoegen ──
cat "$HERE/packages.extra" >> "$PROFILE/packages.x86_64"

# ── 3. Onze bestanden eroverheen ──
cp -a "$HERE/airootfs/." "$PROFILE/airootfs/"

# ── 4. Merk-assets ──
install -Dm644 "$REPO/assets/logo/wallpaper-dark.png" "$PROFILE/airootfs/usr/share/bearly/wallpaper.png"
install -Dm644 "$REPO/assets/logo/logo-light.png"     "$PROFILE/airootfs/usr/share/bearly/logo.png"
install -Dm644 "$REPO/assets/logo/bearhead-light.png" "$PROFILE/airootfs/usr/share/bearly/bear.png"

# SDDM animatie-thema hergebruiken van de Debian-editie
mkdir -p "$PROFILE/airootfs/usr/share/sddm/themes"
cp -a "$REPO/config/includes.chroot/usr/share/sddm/themes/bearlyos" \
      "$PROFILE/airootfs/usr/share/sddm/themes/bearlyos"

# ── 5. Services inschakelen (via systemd-symlinks) ──
A="$PROFILE/airootfs/etc/systemd/system"
mkdir -p "$A/multi-user.target.wants" "$A/sddm.service.wants"
ln -sf /usr/lib/systemd/system/sddm.service          "$A/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service "$A/multi-user.target.wants/NetworkManager.service"
ln -sf /etc/systemd/system/bearly-liveuser.service    "$A/sddm.service.wants/bearly-liveuser.service"

# ── 6. Profiel-branding ──
sed -i \
  -e "s/^iso_name=.*/iso_name=\"bearlyos-glass\"/" \
  -e "s/^iso_label=.*/iso_label=\"BEARLYOS_GLASS\"/" \
  -e "s/^iso_publisher=.*/iso_publisher=\"Bearly IT (Luka Biart)\"/" \
  -e "s/^iso_application=.*/iso_application=\"BearlyOS Glass\"/" \
  -e "s/^iso_version=.*/iso_version=\"${VER}\"/" \
  "$PROFILE/profiledef.sh"

# ── 7. Bouwen ──
mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

ISO_SRC="$(ls -1 "$OUT"/bearlyos-glass-*.iso | head -n1)"
(cd "$OUT" && sha256sum "$(basename "$ISO_SRC")" > "$(basename "$ISO_SRC").sha256")

echo "Klaar: $ISO_SRC"
ls -lh "$OUT"

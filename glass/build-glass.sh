#!/usr/bin/env bash
# Bouwt de BearlyOS Glass live-ISO met archiso (Arch + Hyprland).
# Draai als root in een Arch-container met archiso, git, nodejs en npm.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
REPO="$(dirname "$HERE")"
VER="${DISTRO_VERSION:-dev}"

WORK="/tmp/glass-build"
PROFILE="$WORK/profile"
AIROOT="$PROFILE/airootfs"
OUT="$REPO/out"
CHAOTIC_KEY="3056513887B78AEB"

step() { echo; echo "=== $* ==="; }

# Geeft alleen de pakketten uit een lijst die echt bestaan (waarschuwt voor de rest).
filter_pkgs() {
    local file="$1" p
    while IFS= read -r p; do
        p="${p%%#*}"
        p="${p//[[:space:]]/}"
        [ -z "$p" ] && continue
        if pacman -Si "$p" >/dev/null 2>&1; then
            echo "$p"
        else
            echo "W: pakket '$p' niet gevonden - overgeslagen" >&2
        fi
    done < "$file"
}

# Controleert dat ALLE verplichte pakketten bestaan en meldt alle ontbrekende in één keer.
require_pkgs() {
    local file="$1" p missing=0
    while IFS= read -r p; do
        p="${p%%#*}"
        p="${p//[[:space:]]/}"
        [ -z "$p" ] && continue
        if pacman -Si "$p" >/dev/null 2>&1 || [ -n "$(pacman -Sgq "$p" 2>/dev/null)" ]; then
            echo "$p"
        else
            echo "E: verplicht pakket '$p' niet gevonden" >&2
            missing=1
        fi
    done < "$file"
    return "$missing"
}

# Zoekt de naam van het Calamares-pakket (chaotic-aur kan het onder een andere naam hebben).
pick_calamares() {
    local list c
    list="$(pacman -Ssq '^calamares' 2>/dev/null || true)"
    for c in calamares calamares-git; do
        if grep -qx "$c" <<<"$list"; then echo "$c"; return 0; fi
    done
    grep -vE 'settings|config|branding|extensions|autologin|theme|eos|debian' <<<"$list" | head -n1 || true
}

# Zet uitvoerbare bestanden in file_permissions (mkarchiso bewaart anders geen rechten).
add_exec_perms() {
    local sub="$1" f rel
    [ -d "$AIROOT/$sub" ] || return 0
    while IFS= read -r -d '' f; do
        rel="/${f#"$AIROOT/"}"
        printf 'file_permissions+=([%q]="0:0:755")\n' "$rel" >> "$PROFILE/profiledef.sh"
    done < <(find "$AIROOT/$sub" -type f -perm /111 -print0)
}

rm -rf "$WORK"
mkdir -p "$WORK" "$OUT"

# ── 1. chaotic-aur (voor Calamares en Brave) ──────────────────────
step "chaotic-aur toevoegen"
# De container heeft nog geen eigen sleutel om andere sleutels lokaal mee te ondertekenen.
pacman-key --init
pacman-key --populate archlinux
pacman-key --recv-keys "$CHAOTIC_KEY" --keyserver hkps://keyserver.ubuntu.com
pacman-key --lsign-key "$CHAOTIC_KEY"
pacman -U --noconfirm \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
    'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'
if ! grep -q '^\[chaotic-aur\]' /etc/pacman.conf; then
    printf '\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n' >> /etc/pacman.conf
fi
pacman -Sy

# ── 2. Basisprofiel 'releng' ──────────────────────────────────────
step "archiso-profiel voorbereiden"
cp -r /usr/share/archiso/configs/releng "$PROFILE"

cat >> "$PROFILE/pacman.conf" <<'EOF'

[chaotic-aur]
SigLevel = Optional TrustAll
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# releng zet systemd-networkd/iwd aan; wij gebruiken NetworkManager
rm -rf "$AIROOT/etc/systemd/network"
find "$AIROOT/etc/systemd/system" \
    \( -name 'systemd-networkd*' -o -name 'iwd.service' \) -exec rm -rf {} + 2>/dev/null || true

# ── 3. Pakketten ──────────────────────────────────────────────────
step "installer-pakket zoeken"
echo "Pakketten in de bronnen met 'calamares' in de naam:"
pacman -Ssq calamares | sed 's/^/  /' || true
echo "Relevante pakketten in chaotic-aur:"
pacman -Sl chaotic-aur | grep -iE 'calamares|ckbcomp|kpmcore' | sed 's/^/  /' || true
CALA="$(pick_calamares)"
if [ -z "$CALA" ]; then
    echo "E: geen Calamares-pakket gevonden in de pakketbronnen" >&2
    exit 1
fi
echo "Gekozen installer-pakket: $CALA"

step "pakketlijsten samenstellen"
{
    echo
    echo "# --- BearlyOS Glass ---"
    require_pkgs "$HERE/packages.extra"
    filter_pkgs "$HERE/packages.optional"
    require_pkgs "$HERE/packages.chaotic"
    echo "$CALA"
    filter_pkgs "$HERE/packages.chaotic.optional"
} >> "$PROFILE/packages.x86_64"

# ── 4. Onze bestanden eroverheen ──────────────────────────────────
step "overlay en merk-assets"
cp -a "$HERE/airootfs/." "$AIROOT/"

install -Dm644 "$REPO/assets/logo/wallpaper-dark.png" "$AIROOT/usr/share/bearly/wallpaper.png"
install -Dm644 "$REPO/assets/logo/logo-light.png"     "$AIROOT/usr/share/bearly/logo.png"
install -Dm644 "$REPO/assets/logo/bearhead-light.png" "$AIROOT/usr/share/bearly/bear.png"

# SDDM animatie-thema hergebruiken van de Debian-editie (Qt6-variant van SDDM)
mkdir -p "$AIROOT/usr/share/sddm/themes"
cp -a "$REPO/config/includes.chroot/usr/share/sddm/themes/bearlyos" \
      "$AIROOT/usr/share/sddm/themes/bearlyos"
echo "QtVersion=6" >> "$AIROOT/usr/share/sddm/themes/bearlyos/metadata.desc"

# pacman.conf voor het geinstalleerde systeem (met chaotic-aur, zonder
# de docker-specifieke NoExtract-regels)
grep -vE '^(NoExtract|NoUpgrade)' /etc/pacman.conf \
    | sed -e 's/^#Color/Color/' -e 's/^#ParallelDownloads.*/ParallelDownloads = 5/' \
    > "$AIROOT/etc/pacman.conf"

# ── 5. Claude Code (npm) in het image ─────────────────────────────
step "Claude Code installeren"
mkdir -p "$AIROOT/usr"
npm install -g --prefix "$AIROOT/usr" @anthropic-ai/claude-code
test -e "$AIROOT/usr/bin/claude"

# ── 6. Services inschakelen (systemd-symlinks) ────────────────────
step "services inschakelen"
A="$AIROOT/etc/systemd/system"
mkdir -p "$A/multi-user.target.wants" "$A/sddm.service.wants" "$A/bluetooth.target.wants"
ln -sf /usr/lib/systemd/system/sddm.service            "$A/display-manager.service"
ln -sf /usr/lib/systemd/system/NetworkManager.service  "$A/multi-user.target.wants/NetworkManager.service"
ln -sf /usr/lib/systemd/system/ufw.service             "$A/multi-user.target.wants/ufw.service"
ln -sf /usr/lib/systemd/system/bluetooth.service       "$A/bluetooth.target.wants/bluetooth.service"
ln -sf /usr/lib/systemd/system/bluetooth.service       "$A/dbus-org.bluez.service"
ln -sf /etc/systemd/system/bearly-liveuser.service     "$A/sddm.service.wants/bearly-liveuser.service"
ln -sf /etc/systemd/system/bearly-firstboot.service    "$A/multi-user.target.wants/bearly-firstboot.service"

# ── 7. Merk: profiel, bootmenu, splash ────────────────────────────
step "branding"
sed -i \
    -e "s/^iso_name=.*/iso_name=\"bearlyos-glass\"/" \
    -e "s/^iso_label=.*/iso_label=\"BEARLYOS_GLASS\"/" \
    -e "s/^iso_publisher=.*/iso_publisher=\"Bearly IT (Luka Biart)\"/" \
    -e "s/^iso_application=.*/iso_application=\"BearlyOS Glass\"/" \
    -e "s/^iso_version=.*/iso_version=\"${VER}\"/" \
    "$PROFILE/profiledef.sh"

for d in efiboot grub syslinux; do
    if [ -d "$PROFILE/$d" ]; then
        grep -rlI "Arch Linux" "$PROFILE/$d" | xargs -r sed -i 's/Arch Linux/BearlyOS Glass/g'
    fi
done
[ -f "$PROFILE/syslinux/splash.png" ] && cp "$HERE/assets/splash.png" "$PROFILE/syslinux/splash.png"

# ── 8. Bestandsrechten voor scripts ───────────────────────────────
add_exec_perms usr/local/bin
add_exec_perms usr/lib/node_modules

# ── 9. Bouwen ─────────────────────────────────────────────────────
step "ISO bouwen (mkarchiso)"
mkarchiso -v -w "$WORK/tmp" -o "$OUT" "$PROFILE"

ISO_SRC="$(ls -1 "$OUT"/bearlyos-glass-*.iso | head -n1)"
(cd "$OUT" && sha256sum "$(basename "$ISO_SRC")" > "$(basename "$ISO_SRC").sha256")

echo "Klaar: $ISO_SRC"
ls -lh "$OUT"

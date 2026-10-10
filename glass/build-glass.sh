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

# Probeert een commando een paar keer opnieuw (pakketservers geven soms tijdelijk een 503).
retry() {
    local tries="$1" wait="$2" i=1
    shift 2
    until "$@"; do
        if [ "$i" -ge "$tries" ]; then
            echo "E: '$*' faalde $tries keer" >&2
            return 1
        fi
        echo "W: poging $i/$tries mislukt; opnieuw over ${wait}s..." >&2
        i=$((i + 1))
        sleep "$wait"
    done
}

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

# Bouwt een pakket uit de AUR als gewone gebruiker ("builder", zonder sudo).
# Veiligheid: afhankelijkheden worden als root vanuit de officiële repo's
# geinstalleerd, en alle bronnen moeten van het Calamares-project zelf komen.
build_calamares() {
    local name="$1" dir info bad deps pkg
    dir="$(su builder -c 'mktemp -d /home/builder/aur.XXXXXX')"
    su builder -c "git clone --depth 1 https://aur.archlinux.org/${name}.git ${dir}/${name}" || return 1
    info="$(su builder -c "bash ${WORK}/aur-info.sh ${dir}/${name}")" || return 1
    sed 's/^/  /' <<<"$info"

    # Toegestaan: de officiele Calamares-repo op Codeberg (het project is daar naartoe
    # verhuisd; de oude GitHub-repo is gearchiveerd) en de oude GitHub-locatie.
    bad="$(grep '^SRC .*://' <<<"$info" | grep -vE '://((codeload\.)?github\.com/calamares/|codeberg\.org/Calamares/calamares[/.])' || true)"
    if [ -n "$bad" ]; then
        echo "E: onverwachte bron(nen) in de PKGBUILD van $name:" >&2
        echo "$bad" >&2
        return 1
    fi

    deps="$(grep '^DEP ' <<<"$info" | sed -e 's/^DEP //' -e 's/[<>=].*//' | grep -v '^$' | sort -u | tr '\n' ' ')"
    echo "Afhankelijkheden installeren: $deps"
    # shellcheck disable=SC2086
    pacman -S --noconfirm --needed $deps || return 1

    su builder -c "cd ${dir}/${name} && MAKEFLAGS=-j$(nproc) makepkg --noconfirm --skippgpcheck -f" || return 1
    for pkg in "${dir}/${name}"/*.pkg.tar.*; do
        case "$pkg" in *-debug-*|*.sig) continue ;; esac
        cp "$pkg" "$WORK/localrepo/"
        pacman -Qpq "$pkg" >> "$WORK/pkgnames"
    done
    [ -s "$WORK/pkgnames" ]
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
retry 5 20 pacman-key --recv-keys "$CHAOTIC_KEY" --keyserver hkps://keyserver.ubuntu.com
pacman-key --lsign-key "$CHAOTIC_KEY"
retry 6 30 pacman -U --noconfirm \
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
step "Calamares bouwen uit de AUR (niet beschikbaar in binaire repo's)"
echo "Diagnose - pakketten met 'calamares' in de repo's (leeg = geen):"
pacman -Ssq calamares | sed 's/^/  /' || true

id builder >/dev/null 2>&1 || useradd -m builder
mkdir -p "$WORK/localrepo"
: > "$WORK/pkgnames"

cat > "$WORK/aur-info.sh" <<'EOF'
#!/bin/bash
# Leest bronnen en afhankelijkheden uit een PKGBUILD (draait als gewone gebruiker).
cd "$1" || exit 1
# shellcheck disable=SC1091
source ./PKGBUILD
printf 'SRC %s\n' "${source[@]}"
printf 'DEP %s\n' "${depends[@]}" "${makedepends[@]}"
EOF
chmod 755 "$WORK/aur-info.sh"

CALA_OK=0
for aur in calamares calamares-git; do
    echo "--- poging: AUR/$aur ---"
    if build_calamares "$aur"; then
        CALA_OK=1
        break
    fi
    echo "W: bouwen van AUR/$aur is mislukt" >&2
    : > "$WORK/pkgnames"
done
if [ "$CALA_OK" != "1" ]; then
    echo "E: Calamares kon niet gebouwd worden" >&2
    exit 1
fi
(cd "$WORK/localrepo" && repo-add bearly-local.db.tar.gz ./*.pkg.tar.*)

cat >> "$PROFILE/pacman.conf" <<EOF

[bearly-local]
SigLevel = Optional TrustAll
Server = file://$WORK/localrepo
EOF

step "pakketlijsten samenstellen"
{
    echo
    echo "# --- BearlyOS Glass ---"
    require_pkgs "$HERE/packages.extra"
    filter_pkgs "$HERE/packages.optional"
    require_pkgs "$HERE/packages.chaotic"
    cat "$WORK/pkgnames"
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

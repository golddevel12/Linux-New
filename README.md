# Linux-New

Een eigen Linux-distributie, gebaseerd op **Debian 12 (bookworm)** met de
**XFCE**-desktop. De ISO wordt automatisch gebouwd door GitHub Actions en als
download op de *Releases*-pagina gezet. Je zet hem daarna op een USB-stick en
start je computer ervan op.

## Wat zit erin?

- Live-systeem: opstarten vanaf USB zonder iets te installeren
- XFCE-desktop, Firefox, bestandsbeheer, teksteditor, GParted, Synaptic
- Wifi- en hardwarefirmware (Intel, Realtek, Atheros, Broadcom, AMD/Intel microcode)
- Installatieprogramma (Calamares) om het systeem vast op je schijf te zetten
- Werkt op zowel BIOS- als UEFI-computers (64-bit)

Inloggen in de live-sessie gaat automatisch. Gebruiker: `user`, wachtwoord: `live`.

## 1. Een release maken (ISO laten bouwen)

**Optie A: een officiële release met downloadlink**

Maak een versietag en push die naar GitHub:

```bash
git tag v1.0
git push origin v1.0
```

GitHub Actions bouwt de ISO (dat duurt ongeveer 20–40 minuten) en zet hem op
de **Releases**-pagina van deze repository.

Je kunt ook op GitHub zelf een release maken: ga naar **Releases → Draft a new
release**, kies een nieuwe tag zoals `v1.0` en klik op **Publish**.

**Optie B: een testversie**

Ga naar **Actions → Build ISO → Run workflow**. Als de build klaar is, staat de
ISO onderaan de pagina van die run, onder *Artifacts* (als zip-bestand).

## 2. Downloaden

Ga naar de **Releases**-pagina en download:

- `linux-new-v1.0-amd64.iso`: het image
- `linux-new-v1.0-amd64.iso.sha256`: de controlesom (optioneel)

Download controleren (Linux/macOS):

```bash
sha256sum -c linux-new-v1.0-amd64.iso.sha256
```

## 3. Op een USB-stick zetten

> ⚠️ Alles op de USB-stick wordt gewist. Gebruik een stick van minimaal 4 GB.

**Windows**: gebruik [Rufus](https://rufus.ie). Kies de ISO en klik op *Start*.
Kies **"DD-image-modus"** als Rufus daarom vraagt.

**Windows, macOS of Linux**: gebruik [balenaEtcher](https://etcher.balena.io).
Kies *Flash from file*, selecteer de stick en klik op *Flash*.

**Linux (terminal)**:

```bash
lsblk                                   # zoek je USB-stick, bijv. /dev/sdb
sudo dd if=linux-new-v1.0-amd64.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Vervang `/dev/sdX` door je USB-stick, **niet** door een partitie zoals `/dev/sdb1`
en zeker niet door je harde schijf.

**Ventoy**: heb je [Ventoy](https://www.ventoy.net) op je stick? Dan kopieer je
de ISO er gewoon naartoe.

## 4. Opstarten

1. Steek de USB-stick in je computer en herstart.
2. Open het bootmenu. Meestal gaat dat met **F12**, **F11**, **F8**, **Esc** of
   **F2**, afhankelijk van het merk.
3. Kies de USB-stick.
4. Werkt opstarten niet? Zet **Secure Boot** uit in het BIOS/UEFI.

## Je distro aanpassen

| Wat                        | Waar                                                    |
|----------------------------|---------------------------------------------------------|
| Naam, taal, toetsenbord    | `distro.conf`                                           |
| Programma's toevoegen      | `config/package-lists/*.list.chroot` (één pakket per regel) |
| Eigen bestanden toevoegen  | `config/includes.chroot/` (bijv. `etc/skel/` voor de home-map) |
| Scripts tijdens de build   | `config/hooks/normal/*.hook.chroot`                     |

Pakketnamen zoek je op [packages.debian.org](https://packages.debian.org/bookworm/).

Commit en push je wijzigingen en maak daarna een nieuwe tag (bijv. `v1.1`) voor
een nieuwe release.

> GitHub accepteert geen release-bestanden groter dan **2 GB**. Voeg dus niet
> te veel grote pakketten toe (zoals LibreOffice). Als de ISO te groot wordt,
> laat de build dat weten.

## Lokaal bouwen (optioneel)

Op een Debian 12-machine:

```bash
sudo apt install live-build
sudo ./build.sh
```

Je vindt de ISO daarna in `out/`.

Met Docker kan het ook op een andere Linux-distributie:

```bash
docker run --rm --privileged -v "$PWD":/src -w /src debian:bookworm \
  bash -c "apt-get update && apt-get install -y live-build && ./build.sh"
```

Testen zonder USB-stick kan met QEMU:

```bash
qemu-system-x86_64 -m 4G -enable-kvm -cdrom out/*.iso
```

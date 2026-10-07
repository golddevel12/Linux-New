# BearlyOS 🐻

Mijn eigen Linux-distributie van Bearly IT. Gebaseerd op **Debian 12**, met een
**GNOME**-desktop in **Apple-stijl** (WhiteSur-thema, macOS-achtige dock,
donkere modus, animaties), de **Brave**-browser, volledige **dev-tools** +
**Claude Code**, en een flinke set **security- / pentest-tools**.

De ISO wordt gebouwd door GitHub Actions en als download op de **Releases**-pagina
gezet. Daarna zet je hem op een USB-stick en start je je computer ervan op.

> ⚠️ **Status: nog niet getest.** De distro is tot nu toe alleen opgebouwd, nog
> niet daadwerkelijk gebouwd of opgestart. De eerste echte build gebeurt op
> GitHub (zie stap 1). Kom je iets tegen, stuur dan de foutmelding door.

## Wat zit erin?

- **Desktop:** GNOME met WhiteSur-thema (macOS-look), Dash-to-Dock onderaan,
  donkere modus, jouw logo op het loginscherm en als wallpaper, opstartanimatie.
- **Browser:** Brave (standaard in de dock).
- **Ontwikkelen:** git, VS Code, Neovim, Python, Node.js 20, build-essential,
  en **Claude Code** (open een terminal en typ `claude`).
- **Security / pentesting:** nmap, wireshark, aircrack-ng, hydra, john, hashcat,
  sqlmap, nikto, bettercap, ettercap, kismet, reaver, radare2 en meer; firewall
  met `ufw` / `nftables`; wifi-captures zonder sudo.
- **Werkt normaal:** `sudo` werkt zonder wachtwoord, `git` staat klaar.
- **Hardware:** wifi-/videokaart-firmware inbegrepen; werkt op BIOS én UEFI (64-bit).

Inloggen gaat automatisch. Gebruiker `bear`, wachtwoord `live`.

## 1. Een release maken (ISO laten bouwen)

Maak een versietag en push die:

```bash
git tag v1.0
git push origin v1.0
```

GitHub Actions bouwt de ISO (ongeveer **40–70 minuten**, GNOME is groot) en zet
hem op de **Releases**-pagina.

Alleen even testen zonder release? Ga naar **Actions → Build ISO → Run workflow**.
De ISO staat daarna onder *Artifacts* bij die run.

## 2. Downloaden

Op de **Releases**-pagina staat ofwel één `.iso`, ofwel — omdat een volledige
GNOME-ISO groter is dan de 2 GB die GitHub per bestand toestaat — een paar
`.part`-bestanden die je samenvoegt:

**Linux / macOS**
```bash
cat bearlyos-*.iso.*.part > bearlyos.iso
```

**Windows (PowerShell)**
```powershell
cmd /c copy /b (($(Get-ChildItem *.part | Sort-Object Name).Name) -join "+") bearlyos.iso
```

Controleren (optioneel): vergelijk de uitkomst van `sha256sum bearlyos.iso`
(Linux/macOS) of `Get-FileHash bearlyos.iso` (Windows) met de waarde in het
meegeleverde `.sha256`-bestand.

## 3. Op een USB-stick zetten

> ⚠️ Alles op de USB-stick wordt gewist. Gebruik een stick van minimaal **8 GB**.

- **Windows:** [Rufus](https://rufus.ie) — kies de ISO, klik *Start*, kies
  **"DD-image-modus"** als Rufus daarom vraagt.
- **Alle systemen:** [balenaEtcher](https://etcher.balena.io) — *Flash from file*,
  stick kiezen, *Flash*.
- **Linux (terminal):**
  ```bash
  lsblk                                       # zoek je stick, bijv. /dev/sdb
  sudo dd if=bearlyos.iso of=/dev/sdX bs=4M status=progress oflag=sync
  ```
  Vervang `/dev/sdX` door je stick (niet een partitie als `/dev/sdb1`, en zeker
  niet je harde schijf).

## 4. Opstarten

1. Steek de stick erin en herstart.
2. Open het opstartmenu: meestal **F12**, **F11**, **F8**, **Esc** of **F2**
   (verschilt per merk).
3. Kies de USB-stick.
4. Start hij niet op? Zet **Secure Boot** uit in het BIOS/UEFI.

## Je distro aanpassen

| Wat                                   | Waar                                                        |
|---------------------------------------|-------------------------------------------------------------|
| Naam, taal, toetsenbord, gebruiker    | `distro.conf`                                               |
| Programma's toevoegen/weghalen        | `config/package-lists/*.list.chroot` (één pakket per regel) |
| Extra security-tools                  | `config/hooks/normal/0700-security-extra.hook.chroot`       |
| Uiterlijk / thema / dock / wallpaper  | `config/hooks/normal/0500-theme.hook.chroot`                |
| VS Code weglaten                      | verwijder `config/hooks/normal/0400-vscode.hook.chroot`     |
| Eigen bestanden in de home-map        | `config/includes.chroot/etc/skel/`                          |
| Logo / wallpaper                      | `assets/logo/` (bron van het Bearly-IT-logo)                |

Pakketnamen zoek je op [packages.debian.org](https://packages.debian.org/bookworm/).
Commit en push je wijzigingen en maak een nieuwe tag (bijv. `v1.1`) voor een
nieuwe release.

## Lokaal bouwen (optioneel)

Op een Debian 12-machine:

```bash
sudo apt install live-build
sudo ./build.sh        # ISO komt in out/
```

Met Docker op een andere distro:

```bash
docker run --rm --privileged -v "$PWD":/src -w /src debian:bookworm \
  bash -c "apt-get update && apt-get install -y live-build git curl ca-certificates libcap2-bin && ./build.sh"
```

Testen zonder USB-stick (QEMU):

```bash
qemu-system-x86_64 -m 4G -enable-kvm -cdrom out/bearlyos-*-amd64.iso
```

## Mogelijke volgende stappen

- **Installeren op schijf** (Calamares) toevoegen, zodat je BearlyOS vast kunt
  installeren in plaats van alleen live te draaien.
- Eigen GNOME-extensies of een eigen opstart-/inlog-animatie.
- Metasploit / Burp Suite toevoegen (zitten niet in Debian; aparte repo nodig).

---

Gebruik de security-tools uitsluitend op systemen en netwerken waarvoor je
uitdrukkelijk toestemming hebt.

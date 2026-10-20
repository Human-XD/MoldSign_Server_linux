# MoldSign Server for Linux — eID card fix

**[Română](#română) · [English](#english)**

> ⚠️ **Proiect neoficial / Unofficial project.** Nu este afiliat cu STISC sau Bit4id. Not affiliated with STISC or Bit4id.

---

## Română

### Problema

Versiunea oficială de Linux a **MoldSign Desktop Suite** ([semnatura.md](https://semnatura.md/productsdownloads)) pornește, dar **nu vede cartea de identitate electronică (buletinul cu cip)**. Pe msign.gov.md apare:

> *Nu s-a găsit niciun certificat! Verificați dacă ați inserat cardul sau token-ul Dvs…*

Cauza: pachetul de Linux include doar drivere pentru token-uri USB (Feitian ePass2003 și SafeNet eToken). Driverele pentru buletin sunt publicate oficial doar pentru Windows și macOS.

### Soluția

Scriptul `install-moldsign.sh`:

1. Instalează serviciul de carduri inteligente (`pcscd`, `libccid`, `pcsc-tools`) și aplică permisiunile pentru cititor.
2. Descarcă **MoldSign** de pe semnatura.md și **Bit4id Universal Middleware** (driver PKCS#11) de pe site-ul oficial Bit4id și verifică sumele de control SHA-256.
3. Instalează MoldSign în `~/MoldSign` și adaugă driverul Bit4id, care citește buletinul.
4. Creează scurtături în meniu, pornire automată la login și pornește serverul.

Nu este inclus niciun fișier MoldSign sau Bit4id în acest depozit — totul se descarcă din sursele oficiale.

### Cerințe

- Ubuntu sau Debian, 64-bit (x86_64)
- Cititor de carduri compatibil CCID (testat cu **Bit4id miniLector EVO**)
- Buletin de identitate electronic cu certificat de semnătură valabil
- Conexiune la internet și drepturi `sudo`

### Instalare

Rulați ca utilizator obișnuit (**fără** `sudo`), într-un terminal:

```bash
curl -fLO https://raw.githubusercontent.com/Human-XD/MoldSign_Server_linux/main/install-moldsign.sh
bash install-moldsign.sh
```

Scriptul va cere parola o singură dată, pentru instalarea pachetelor de sistem.

Apoi:

1. Introduceți buletinul în cititor (dacă cititorul era deja conectat, scoateți-l și conectați-l din nou o dată).
2. Verificați că apare iconița MoldSign lângă ceas.
3. Deschideți linkul de semnare de pe msign.gov.md, alegeți MoldSign, certificatul și introduceți PIN-ul.

### Dezinstalare

```bash
bash install-moldsign.sh --uninstall
```

### Opțiuni

| Variabilă | Efect |
|---|---|
| `MOLDSIGN_TAR=/cale/MoldSign_Install.tar.xz` | folosește o copie locală în loc de descărcare |
| `BIT4ID_ZIP=/cale/Bit4id_Middleware.zip` | folosește o copie locală în loc de descărcare |
| `ALLOW_UNVERIFIED=1` | acceptă o versiune nouă publicată de STISC/Bit4id (suma de control diferă) |
| `INSTALL_DIR=...` | alt director de instalare (implicit `~/MoldSign`) |
| `NO_SYSTEM=1` | sare peste instalarea pachetelor de sistem |
| `NO_DESKTOP=1` | fără scurtături/pornire automată și fără pornirea serverului |

Exemplu: `ALLOW_UNVERIFIED=1 bash install-moldsign.sh`

### Depanare

| Simptom | Ce faceți |
|---|---|
| *Nu s-a găsit niciun certificat* | Rulați `pcsc_scan` — trebuie să apară cititorul și „Card inserted”. Dacă nu apare, scoateți și reconectați cititorul. Verificați jurnalul `~/MoldSign/log/err_server.log` (căutați „Card inserted” și „found:1”). |
| *O astfel de cerere de semnare nu a fost găsită* | Eroare a site-ului msign.gov.md: cererea a expirat sau linkul s-a pierdut. Deschideți din nou linkul original sau cereți expeditorului un link nou. |
| `LIBUSB_ERROR_ACCESS` în `journalctl -u pcscd` | Scoateți și reconectați cititorul. |
| *Checksum mismatch* | STISC sau Bit4id au publicat o versiune nouă. Rulați cu `ALLOW_UNVERIFIED=1`. |
| Serverul nu pornește | Meniu → „MoldSign Server”, sau `~/MoldSign/MoldSign_Server.sh`. Oprire: `~/MoldSign/terminate.sh`. |

### Cum funcționează (tehnic)

MoldSign Server (Java) ascultă pe `localhost.cts.md:18480/18443`; pagina msign.gov.md comunică cu el din browser. Lista de drivere PKCS#11 este în `~/MoldSign/MoldSignData/Server/PKCS11.properties`. Scriptul copiază `libbit4xpki.so`, `libbit4xpki.so.conf` și `libbit4xpki.so.rc/` în `~/MoldSign/native_lib/` și setează:

```
driver_lib=libbit4xpki.so|libcastle.1.0.0.so|libeToken.so
```

### Licență și aviz

Scriptul și documentația sunt sub licența [MIT](LICENSE). **MoldSign Desktop Suite** este proprietatea IP Serviciul Tehnologia Informației și Securitate Cibernetică (STISC); **Bit4id Universal Middleware** este proprietatea Bit4id. Acestea nu sunt distribuite aici și se folosesc conform condițiilor proprietarilor lor. Acest proiect nu este oficial și nu este susținut de STISC sau Bit4id. Pentru suport oficial: [semnatura.md](https://semnatura.md), tel. 022 820 911.

---

## English

### The problem

The official Linux build of **MoldSign Desktop Suite** ([semnatura.md](https://semnatura.md/productsdownloads)) starts, but **does not see the Moldovan electronic ID card**. msign.gov.md shows:

> *Nu s-a găsit niciun certificat!* ("No certificate found")

Cause: the Linux package only ships drivers for USB tokens (Feitian ePass2003 and SafeNet eToken). The ID-card drivers are officially published for Windows and macOS only.

### The fix

`install-moldsign.sh`:

1. Installs the smart-card service (`pcscd`, `libccid`, `pcsc-tools`) and applies reader permissions.
2. Downloads **MoldSign** from semnatura.md and the **Bit4id Universal Middleware** (PKCS#11 driver) from Bit4id's official site, and verifies their SHA-256 checksums.
3. Installs MoldSign in `~/MoldSign` and adds the Bit4id driver, which reads the eID card.
4. Creates menu entries and login autostart, and starts the server.

No MoldSign or Bit4id files are included in this repository — everything is downloaded from official sources.

### Requirements

- Ubuntu or Debian, 64-bit (x86_64)
- CCID-compatible card reader (tested with **Bit4id miniLector EVO**)
- Moldovan electronic ID card with a valid signing certificate
- Internet connection and `sudo` rights

### Install

Run as your normal user (**not** with `sudo`), in a terminal:

```bash
curl -fLO https://raw.githubusercontent.com/Human-XD/MoldSign_Server_linux/main/install-moldsign.sh
bash install-moldsign.sh
```

The script asks for your password once, to install system packages.

Then:

1. Insert the ID card (if the reader was already plugged in, unplug and replug it once).
2. Check that the MoldSign icon appears next to the clock.
3. Open your msign.gov.md signing link, choose MoldSign, pick the certificate and enter your PIN.

### Uninstall

```bash
bash install-moldsign.sh --uninstall
```

### Options

| Variable | Effect |
|---|---|
| `MOLDSIGN_TAR=/path/MoldSign_Install.tar.xz` | use a local copy instead of downloading |
| `BIT4ID_ZIP=/path/Bit4id_Middleware.zip` | use a local copy instead of downloading |
| `ALLOW_UNVERIFIED=1` | accept a newer release from STISC/Bit4id (checksum differs) |
| `INSTALL_DIR=...` | different install location (default `~/MoldSign`) |
| `NO_SYSTEM=1` | skip installing system packages |
| `NO_DESKTOP=1` | no menu/autostart entries and don't start the server |

Example: `ALLOW_UNVERIFIED=1 bash install-moldsign.sh`

### Troubleshooting

| Symptom | What to do |
|---|---|
| *Nu s-a găsit niciun certificat* (no certificate found) | Run `pcsc_scan` — the reader and "Card inserted" must appear. If not, unplug and replug the reader. Check `~/MoldSign/log/err_server.log` for "Card inserted" and "found:1". |
| *O astfel de cerere de semnare nu a fost găsită* (signing request not found) | A msign.gov.md error: the request expired or the link was lost. Open the original link again or ask the sender for a new one. |
| `LIBUSB_ERROR_ACCESS` in `journalctl -u pcscd` | Unplug and replug the reader. |
| *Checksum mismatch* | STISC or Bit4id published a new version. Re-run with `ALLOW_UNVERIFIED=1`. |
| Server not running | Menu → "MoldSign Server", or `~/MoldSign/MoldSign_Server.sh`. Stop it with `~/MoldSign/terminate.sh`. |

### How it works (technical)

MoldSign Server (Java) listens on `localhost.cts.md:18480/18443`; the msign.gov.md page talks to it from the browser. The PKCS#11 driver list lives in `~/MoldSign/MoldSignData/Server/PKCS11.properties`. The script copies `libbit4xpki.so`, `libbit4xpki.so.conf` and `libbit4xpki.so.rc/` into `~/MoldSign/native_lib/` and sets:

```
driver_lib=libbit4xpki.so|libcastle.1.0.0.so|libeToken.so
```

### License and disclaimer

The script and documentation are [MIT](LICENSE) licensed. **MoldSign Desktop Suite** is the property of IP Serviciul Tehnologia Informației și Securitate Cibernetică (STISC); **Bit4id Universal Middleware** is the property of Bit4id. They are not distributed here and are used under their owners' own terms. This project is unofficial and not endorsed by STISC or Bit4id. For official support: [semnatura.md](https://semnatura.md), phone +373 22 820 911.

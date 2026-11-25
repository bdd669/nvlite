# NVLITE

**Extract only what you need from an NVIDIA driver package.**

NVLITE is a single-file Windows batch script. Drag an official NVIDIA driver `.exe` onto it,
and it produces a slimmed-down installation folder — no NVIDIA App, no telemetry, no auto-updater.

```
Official package 988 MB  →  full extract 3.8 GB  →  NVLITE keeps ~3.1 GB of clean install source
```

[中文说明](README.zh-CN.md)

---

## What it actually does

It is **not** a driver installer. It unpacks a driver package and keeps only a whitelist of entries.

| Step | Action |
|---|---|
| 1 | Takes a driver `.exe` (drag-and-drop, or paste the path) |
| 2 | Finds an extractor: NanaZip → 7-Zip → Bandizip |
| 3 | **Extracts only the whitelist**, everything else is never decompressed |
| 4 | Verifies required files are present |
| 5 | Filters `setup.cfg` to drop consent-page declarations pointing at files we don't extract |
| 6 | Generates `Install_Silent.bat` for unattended installation |
| 7 | Writes `nvlite_log.txt` with the extraction log |

The core is **one `7z x` command**. Everything else is guard rails.

## What it keeps

```
Display.Driver     GPU driver + NVIDIA Control Panel
NVI2               installer engine (without it Setup.exe won't start)
setup.exe          installation entry point
setup.cfg          installation config
ListDevices.txt    device list
EULA.txt           license text (optional, some packages don't ship it)
PhysX              physics engine        (optional, see config)
HDAudio            HDMI/DP audio          (optional, see config)
```

## What it drops

| Dropped | What you lose |
|---|---|
| NVIDIA App / GeForce Experience | recording, game filters, auto-optimization, in-game overlay |
| NvContainer background services | the runtime NVIDIA App needs (Control Panel unaffected) |
| Telemetry components | no hardware info reporting to NVIDIA |
| Auto-updater | no silent driver pushes |
| Ansel directory | in-game screenshot tool |
| NVPCF / Display.Optimus (laptop) | Dynamic Boost, legacy hybrid graphics switching |
| PPC / USB-C driver | display output over the GPU's USB-C port |

## Requirements

- Windows 10 / 11 x64
- One of: **NanaZip** (recommended), **7-Zip**, or **Bandizip**

The script looks for the command-line binary: `NanaZipC.exe`, `7z.exe`/`7za.exe`/`7zz.exe`, or `bz.exe`.
GUI versions (`NanaZip.exe`, `7zG.exe`, `Bandizip.exe`) are **not** supported — they have no usable CLI.

You can also drop `NanaZipC.exe` next to the script.

## Usage

```
1. Drag the official NVIDIA driver .exe onto NVLITE.bat
2. Wait 1-2 minutes
3. Open the generated folder (e.g. 621.40-Desktop-Win11)
4. Install the driver, either way works:
   - double-click Setup.exe and click through (recommended, shows GUI errors)
   - or right-click Install_Silent.bat → Run as administrator (fully unattended)
```

## Configuration

Three variables near the top of the script control how much gets kept:

```bat
rem Required, do not touch
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"

rem Optional components — delete a word to skip it
rem   PhysX    ~50MB, only a few old games use GPU physics
rem   HDAudio   ~20MB, only needed if you play sound through monitor/TV speakers
set "EXTRA=PhysX HDAudio EULA.txt"

rem Post-extract deletions. Leave empty.
set "DROP="
set "DROPDIR="
```

**Do not fill `DROP` / `DROPDIR`.** Deleting files inside `Display.Driver` breaks the installer:
`NvCamera` removal causes *"required files are missing"* and installation aborts during the
System check. See [docs/technical-notes.md](docs/technical-notes.md) for the full investigation.

## Scope — read before using

### Good for

- Desktop with a discrete NVIDIA GPU (GTX 10 series and newer)
- You just want the driver, not the NVIDIA software suite
- You want to avoid telemetry and auto-updates
- You want to save disk space

### Not recommended for

- **Laptops.** `NVPCF` is not extracted, so Dynamic Boost may stop working and gaming
  framerates may drop slightly under load. Use the official package instead.
- Anyone who needs GeForce Experience features (recording, filters, auto-optimization)
- Quadro / IT management scenarios that rely on `NVWMI`

## FAQ

**Will it cause stutter, frame drops, or instability?**
No. The driver files are NVIDIA's original signed binaries, byte-for-byte unchanged. Verify:

```powershell
(Get-AuthenticodeSignature C:\Windows\System32\drivers\nvlddmkm.sys).Status
```

`Valid` means it is the genuine original.

**Will anti-cheat flag it?**
No. Anti-cheat checks driver signatures and running services. The signature is intact, and
NVLITE removes a service (telemetry) rather than adding one.

**NVIDIA Control Panel won't open.**
The background container service is not installed. Install "NVIDIA Control Panel" from the
Microsoft Store, or use the classic Control Panel package.

**How do I update drivers?**
Download a new official package and drag it onto the script again. There is no auto-updater —
that is the point.

**Will it delete my files?**
No. The output folder name is deterministic (`<version>-Desktop-Win11` or `-Laptops-Win11`),
and the script only deletes a folder it created itself, identified by `nvlite_log.txt`
inside it. If a folder with that name already exists but lacks the marker, the script stops
and asks you to rename or remove it manually.

## Verified

| Driver | Package | Result |
|---|---|---|
| 621.24 | desktop, 991 MiB | generated, installed, driver active |
| 621.40 | desktop, 988 MiB | generated, installed, driver active |

Tested on Windows 11 x64 with NanaZip (Microsoft Store version) as the extractor.

## Known limitations

- The driver package path **must not contain parentheses**, because `for /f` parses the
  command inside `('...')` and a `)` there terminates the loop header early.
  Spaces, Chinese characters, `&` and `!` in the path are fine.
- Bandizip's `bz.exe` support is untested for NVIDIA's self-extracting package.
- Only accepts `.exe` driver packages, not `.zip`.

## License

MIT — see [LICENSE](LICENSE).

Not affiliated with NVIDIA. NVIDIA, GeForce, and related marks are trademarks of NVIDIA Corporation.

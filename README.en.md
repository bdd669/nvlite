# NVLITE

A batch script that unpacks an NVIDIA driver package and keeps only the driver.

Drag an official driver `.exe` onto it. You get a folder about 700 MB smaller than a full
extract, containing the driver, the installer, and nothing else.

[中文说明](README.md)

> **This code was written by AI.** What has been tested, what hasn't, and what can go wrong
> is all in [DISCLAIMER.md](DISCLAIMER.md). Worth a look before you run it.

---

## Why

NVIDIA driver packages ship with an App, telemetry, an auto-updater, and a screenshot tool
most people never open. If you just want the driver, there is no official way to get only that.
NVLITE is a small script that pulls out the parts needed to install and drops the rest.

It does not modify the driver itself. Every file that ends up in the output folder is an
unaltered, signed binary from NVIDIA's own package.

## Usage

1. Drag the official NVIDIA driver `.exe` onto `NVLITE.bat`
2. Wait a minute or two
3. Open the folder it created (`621.40-Desktop-Win11` or similar)
4. Run `Setup.exe` inside it

Step 4 also has a shortcut: right-click `Install_Silent.bat` and run as administrator. Same
result, no clicking, but if something goes wrong you only get an exit code instead of a
dialog. I usually just use `Setup.exe`.

You need one of these installed, because the driver package is a 7-Zip self-extractor:

- **NanaZip** — `NanaZipC.exe` (tested)
- **7-Zip** — `7z.exe`, `7za.exe`, `7zz.exe`, `7zr.exe`
- **Bandizip** — `bz.exe`
- **WinRAR** — `WinRAR.exe`

Only the command-line versions work. Windows' built-in "Extract All" cannot read this format.
The script searches the script's own folder, then common install locations, then `PATH`.
If it still can't find one, you can set `ZMANUAL` at the top of the script to a full path.

## What gets kept

```
Display.Driver      the driver itself, plus the service the Control Panel needs
NVI2                installer engine — Setup.exe won't start without it
setup.exe           installation entry point
setup.cfg           installer config
ListDevices.txt     device list
EULA.txt            license text
PhysX               physics engine        (optional, see config)
HDAudio             HDMI/DP audio          (optional, see config)
```

## What gets dropped

The whole extraction is limited to the list above, so these are never decompressed at all:

- NVIDIA App / GeForce Experience
- the background container services NVIDIA App runs on
- telemetry
- the auto-updater
- Ansel

There is also a post-extraction filter that removes consent-page declarations from
`setup.cfg`. Those declarations point at HTML files inside NVIDIA App's folder, which we
don't extract, and leaving them in makes the installer fail looking for missing files.

## Config

Three variables near the top:

```bat
set "REQ=Display.Driver NVI2 setup.exe setup.cfg ListDevices.txt"
set "EXTRA=PhysX HDAudio EULA.txt"
set "DROP="
set "DROPDIR="
```

`EXTRA` is where you trim further. Drop `PhysX` to save about 50 MB (only a handful of older
games use GPU physics). Drop `HDAudio` to save about 20 MB (only matters if you play sound
through monitor or TV speakers — headphones and desktop speakers don't use it).

**Leave `DROP` and `DROPDIR` empty.** I've tried deleting files inside `Display.Driver` and
it does not work. Removing `NvCamera` made the installer abort with "required files are
missing" during its System check. Details in [docs/technical-notes-zh.md](docs/technical-notes-zh.md).

## The Control Panel situation

Since driver `32.0.16.1060` (roughly the 610 series), NVIDIA stopped bundling the classic
Control Panel with the driver. It now lives inside NVIDIA App as a sub-component.

So on a current driver, this script produces an installation without a Control Panel. You
have two options:

1. Install **NVIDIA Control Panel** from the Microsoft Store afterwards (it's a standalone
   app, does not require NVIDIA App)
2. Use the official full package if you need the App

I have not tested option 1 myself. The container service it depends on (`Display.NvContainer`)
is inside `Display.Driver` and does get extracted, so it should work, but I can't promise it.

On drivers before 610, the Control Panel is still in the package and this whole section
doesn't apply.

## Laptops

Don't use this on a laptop. `NVPCF` isn't extracted, which means Dynamic Boost may stop
working and games can run slower when plugged in. Use the official package instead.

## Other things worth knowing

- **Frame drops or instability?** The driver files are untouched NVIDIA binaries. Check the
  signature yourself:
  ```powershell
  (Get-AuthenticodeSignature C:\Windows\System32\drivers\nvlddmkm.sys).Status
  ```
  `Valid` means it's the genuine signed file.

- **Anti-cheat?** It checks driver signatures and running services. The signature is intact,
  and this removes a service rather than adding one.

- **Will it delete my files?** The output folder name is deterministic, and the script only
  deletes a folder it created itself — it looks for `nvlite_log.txt` inside. If a folder with
  that name exists without the marker, it stops and asks you to rename or remove it.

- **Updating drivers?** Download the new package and drag it on again. There's no auto-updater,
  which is the point.

- **Only `.exe` packages.** Not `.zip`.

- **Path limitation.** The driver package path cannot contain parentheses. `for /f` parses the
  command inside `('...')` and a `)` there breaks it. Spaces, Chinese characters, `&` and `!`
  are fine.

## Tested

| Driver | Package | Result |
|---|---|---|
| 621.24 | desktop, 991 MiB | generated, installed, driver active |
| 621.40 | desktop, 988 MiB | generated, installed, driver active |

Windows 11 x64, NanaZip (Microsoft Store version) as the extractor. Bandizip and WinRAR
support is written but untested — if either fails, use NanaZip.

## License

MIT. See [LICENSE](LICENSE).

Not affiliated with NVIDIA. NVIDIA, GeForce and related marks are trademarks of
NVIDIA Corporation.

## For whoever maintains this next

Project conventions, current state, open items and past decisions live in
[`AGENTS.md`](AGENTS.md) and [`HANDOFF.md`](HANDOFF.md).

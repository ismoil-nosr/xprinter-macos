# Open Xprinter for macOS

A native USB label driver and printing app for **Xprinter XP-330B**, with an offline installer for **macOS 14+ on Apple Silicon and Intel**.

[Download the installer](https://github.com/ismoil-nosr/xprinter-macos/releases/latest) · [Installation](docs/INSTALL.md) · [Русский](docs/README.ru.md) · [Report a problem](https://github.com/ismoil-nosr/xprinter-macos/issues)

Print labels from Chrome, Preview and other Mac apps, or use **Open Xprinter** to create barcodes and QR codes, import a PDF/image, and print CSV batches. The driver locates the start of gap/mark labels before each job, preventing a correctly sized label from starting halfway across a gap.

## Get started

1. Download the `.pkg` from Releases and install it. The first release is **unsigned by Apple**; follow the [macOS approval instructions](docs/INSTALL.md#unsigned-first-release).
2. Connect your XP-330B over USB, turn it on, and load labels.
3. Open **Open Xprinter** in Applications. Choose the loaded label size, stock type and actual gap/mark height. Click **Set up printer** if needed, then **Save as default for other apps**.
4. Print one label before sending a batch. In other apps choose **Xprinter XP-330B Labels (Open Source)** and the matching paper size.

The starting profile is **58 mm across the roll × 40 mm in the feed direction**, with a **2 mm gap**. This is a starting point, not a promise that every roll has a 2 mm gap. Width always means across the print head; height means in the direction the labels move.

## What is included

- A MIT-licensed CUPS raster-to-TSPL driver, written in C and linked to macOS's CUPS library. No proprietary Xprinter driver, Rosetta, Python, Homebrew or online download is needed to print.
- A universal Swift app with physical-size preview, Code 128, Unicode QR, text labels, PDF/image import and UTF-8 CSV batches.
- Common metric sizes, custom sizes, gap labels, black marks and continuous rolls; adjustable darkness and speed.
- An idempotent Installer package with USB discovery, clear setup when unplugged, explicit selection when multiple devices are connected, and a scoped uninstaller.

The app generates barcodes at integer printer-dot sizes, keeps quiet zones, and rejects codes that would be too dense for the chosen label. Its “sent” status means CUPS accepted the job; inspect the first physical label and scan the code to confirm the result.

## Compatibility and scope

| Item | Support |
| --- | --- |
| Printer | XP-330B in TSPL label mode, USB |
| Print head | 203 dpi, up to 76 mm printable width |
| Mac | Apple Silicon and Intel, macOS 14 or newer |
| Label sizes | 30×20, 40×30, 50×30, 50×50, 58×40, 60×40, 70×50, 76×50, 58×100, 76×150 mm; custom 20–76 × 10–1000 mm |
| Languages | English app; English and Russian setup documentation; Unicode label text |
| Other Xprinter models, Bluetooth, Ethernet | Not supported by this release |

This is an independent project, not an official Xprinter product. Firmware variants and other rolls need hardware verification. The [validation record](docs/VALIDATION.md) separates physical checks from automated ones. A 4×6 inch label is wider than this printer's head; use a suitable template rather than shrinking a shipping barcode until it is unreadable.

## Why labels split across gaps

macOS sends a PDF through a raster driver. A PDF's orientation, a printer's paper size and the physical feed direction must agree. A preview can look correct while the printer is configured to feed 58 mm for a roll whose labels are only 40 mm long. A second problem is starting a job without finding the next label origin. This project uses metric media identifiers that retain the physical dimensions and emits `SIZE`, `GAP`/`BLINE`, then `HOME` before the first bitmap for gap/mark stock. It does not home continuous receipt rolls.

Wrong roll dimensions, a dirty/misaligned sensor, receipt mode or inaccurate gap settings still require correction; software cannot infer every roll from USB identification alone. See [troubleshooting](docs/TROUBLESHOOTING.md).

## Build and test

On macOS with Xcode or its Command Line Tools and Python 3 for building:

```sh
git clone https://github.com/ismoil-nosr/xprinter-macos.git
cd xprinter-macos
./scripts/build.sh
./scripts/test.sh
```

`dist/` contains a universal `.pkg`. The build uses only Apple frameworks and tools. Tests cover pixel polarity and padding, copies, multiple pages, malformed input, the CUPS PDF rasterizer, QR/barcode decoding from the final TSPL bitmap, setup input validation and package contents. CI also installs, reinstalls and uninstalls the package on fresh Mac runners without a connected printer.

See [development and release instructions](docs/DEVELOPMENT.md) for architecture, signing and notarization. Contributions and hardware reports are welcome; please read [CONTRIBUTING.md](CONTRIBUTING.md).

## Uninstall

Close the app, finish or cancel its pending print jobs, then run:

```sh
sudo /Library/Printers/OpenXprinter/uninstall.sh
```

Use `--dry-run` to preview. The uninstaller removes only this project's queue, app, driver and package receipt. It preserves your documents, preferences and other printers.

## License

[MIT](LICENSE), copyright Ismoil Nosr. All distributed project code, the PPD and app are open source. Proprietary vendor binaries, vendor PPDs and SDK manuals are not bundled. macOS libraries and frameworks remain covered by Apple's licenses. Xprinter is a trademark of its respective owner.

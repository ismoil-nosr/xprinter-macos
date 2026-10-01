# Open Xprinter for macOS

[![Build, test and package](https://github.com/ismoil-nosr/xprinter-macos/actions/workflows/build.yml/badge.svg)](https://github.com/ismoil-nosr/xprinter-macos/actions/workflows/build.yml)

A native USB label driver and printing app for **Xprinter XP-330B**, with an offline installer for **macOS 14+ on Apple Silicon and Intel**.

[Download the installer](https://github.com/ismoil-nosr/xprinter-macos/releases/latest) · [Installation](docs/INSTALL.md) · [Русский](docs/README.ru.md) · [简体中文](docs/README.zh-CN.md) · [Report a problem](https://github.com/ismoil-nosr/xprinter-macos/issues)

Print labels from Chrome, Preview and other Mac apps, or use **Open Xprinter** to create barcodes and QR codes, import a PDF/image, and print CSV batches. The driver locates the start of gap/mark labels before each job, preventing a correctly sized label from starting halfway across a gap.

## Get started

1. Download the `.pkg` from Releases and install it. The current release is **unsigned by Apple**; follow the [macOS approval instructions](docs/INSTALL.md#unsigned-first-release).
2. Connect your XP-330B over USB, turn it on, and load labels.
3. Open **Open Xprinter** in Applications. Choose the loaded label size, stock type and actual gap/mark height. Click **Set up printer** if needed, then **Save as default for other apps**.
4. Print one label before sending a batch. In other apps choose **Xprinter XP-330B Labels (Open Source)** and the matching paper size.

The starting profile is **58 mm across the roll × 40 mm in the feed direction**, with a **2 mm gap**. This is a starting point, not a promise that every roll has a 2 mm gap. Width always means across the print head; height means in the direction the labels move.

Choose **English**, **Русский**, **简体中文**, or **System default** from the app's top-right language menu. Switching takes effect immediately and is remembered for next launch. Your label content, imported file and printer settings stay the same. Chinese and Russian users can follow the linked guides and contribute in their own language.

## What is included

- A MIT-licensed CUPS raster-to-TSPL driver, written in C and linked to macOS's CUPS library. No proprietary Xprinter driver, Rosetta, Python, Homebrew or online download is needed to print.
- A universal Swift app with physical-size preview, Code 128, Unicode QR, text labels, PDF/image import and UTF-8 CSV batches.
- English, Russian and Simplified Chinese interface, menus, help and app errors; localized installer pages and usage guides.
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
| Languages | English, Russian and Simplified Chinese app and usage guides; Unicode label text |
| Other Xprinter models, Bluetooth, Ethernet | Not supported by this release |

This is an independent project, not an official Xprinter product. Firmware variants and other rolls need hardware verification. The [validation record](docs/VALIDATION.md) separates physical checks from automated ones. A 4×6 inch label is wider than this printer's head; use a suitable template rather than shrinking a shipping barcode until it is unreadable.

## Why labels split across gaps

macOS sends a PDF through a raster driver. A PDF's orientation, a printer's paper size and the physical feed direction must agree. A preview can look correct while the printer is configured to feed 58 mm for a roll whose labels are only 40 mm long. A second problem is starting a job without finding the next label origin. This project uses metric media identifiers that retain the physical dimensions and emits `SIZE`, `GAP`/`BLINE`, then `HOME` before the first bitmap for gap/mark stock. It does not home continuous receipt rolls.

Wrong roll dimensions, a dirty/misaligned sensor, receipt mode or inaccurate gap settings still require correction; software cannot infer every roll from USB identification alone. See [troubleshooting](docs/TROUBLESHOOTING.md).

## AI / MCP access

The optional [Open Xprinter MCP server](https://github.com/ismoil-nosr/xprinter-mcp) lives in its own repository. AI clients on macOS, Windows and Linux can prepare labels, review a preview, submit prints and check their jobs using the same MCP API. Local clients use stdio; remote clients use SSH or an authenticated HTTPS endpoint. The USB backend runs on the Mac with the printer connected.

Open Xprinter **0.3.0+** provides a bounded headless renderer shared with the GUI. It only creates PDFs/previews; the MCP component owns authorization and print submission. MCP is optional and requires Node 24+ on the server Mac. Installing this `.pkg` alone does not open a network port or require Node. See the [renderer contract](docs/MCP-RENDERER.md).

## Build and test

On macOS with Xcode or its Command Line Tools and Python 3 for building:

```sh
git clone https://github.com/ismoil-nosr/xprinter-macos.git
cd xprinter-macos
./scripts/build.sh
./scripts/test.sh
```

`dist/` contains a universal `.pkg`. The build uses only Apple frameworks and tools. Tests cover pixel polarity and padding, copies, multiple pages, malformed input, the CUPS PDF rasterizer, QR/barcode decoding from the final TSPL bitmap, setup input validation and package contents. CI also installs, reinstalls and uninstalls the package on fresh Mac runners without a connected printer.

See [development and release instructions](docs/DEVELOPMENT.md) for architecture, signing and notarization. Contributions and hardware reports are welcome in English, Russian or Chinese; please read [CONTRIBUTING.md](CONTRIBUTING.md), the [中文贡献指南](docs/CONTRIBUTING.zh-CN.md), and the [translation guide](docs/TRANSLATING.md).

## Uninstall

Close the app, finish or cancel its pending print jobs, then run:

```sh
sudo /Library/Printers/OpenXprinter/uninstall.sh
```

Use `--dry-run` to preview. The uninstaller removes only this project's queue, app, driver and package receipt. It preserves your documents, preferences and other printers.

## License

[MIT](LICENSE), copyright Ismoil Nosr. All distributed project code, the PPD and app are open source. Proprietary vendor binaries, vendor PPDs and SDK manuals are not bundled. macOS libraries and frameworks remain covered by Apple's licenses. Xprinter is a trademark of its respective owner.

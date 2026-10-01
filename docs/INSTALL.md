# Installation

## Requirements

macOS 14 or later, an Intel or Apple Silicon Mac, an administrator account, an XP-330B connected by USB, and direct thermal labels. The printer must be in TSPL label mode. The package can be installed before connecting the printer and works offline after downloading.

## Unsigned first release

Version 0.2.0 has an **unsigned Installer package** and **ad-hoc-signed executables**. Ad-hoc signatures verify code integrity; they do not identify a developer to Apple. This release is not notarized. macOS may ask you to approve both the downloaded installer and the app.

Download only from [this repository's Releases](https://github.com/ismoil-nosr/xprinter-macos/releases). If macOS blocks opening the package, attempt to open it once, then use **System Settings → Privacy & Security → Open Anyway** for that package, authenticate, and open it again. If the app is separately blocked, approve that specific app the same way. Do not disable Gatekeeper, SIP or other system protections. Apple's [instructions for opening an app from an unidentified developer](https://support.apple.com/guide/mac-help/open-a-mac-app-from-an-unidentified-developer-mh40616/mac) describe the approval process.

The release includes SHA-256 checksums. You can compare a downloaded package with `shasum -a 256 package.pkg`. A checksum detects download changes; an unsigned checksum from the same site is not a substitute for Developer ID trust.

## Setup

1. Double-click the `.pkg` and complete Installer. It installs **Open Xprinter.app** into `/Applications` and the local driver into `/Library/Printers/OpenXprinter`.
2. Connect USB directly or through a working USB hub, turn on the printer, load a roll, and close the cover.
3. Open **Open Xprinter**. If asked, click **Set up printer** and approve the normal macOS administrator dialog. If multiple XP-330Bs are connected, select the intended USB device first.
4. Choose your label dimensions and stock. **58 × 40 mm** means 58 mm across the head and 40 mm along the feed direction. Measure the empty backing gap separately; it is not included in the label's 40 mm height.
5. Click **Save as default for other apps**. This saves printer-wide defaults; applications can still override them, so check the print preview's paper size.
6. Print one label. Check that all content stays on one label and scan its barcode or QR before printing a batch.

The installer leaves your current default printer and existing vendor queues intact. This project's queue is named `XP330B_OpenSource` and appears as **Xprinter XP-330B Labels (Open Source)**.

## Language

The app's top-right menu offers **English**, **Русский**, **简体中文**, and **System default**. Selection takes effect immediately and persists across launches without changing your label content or printer settings. Installer welcome/conclusion pages follow the system language. See the [Russian](README.ru.md) and [Chinese](README.zh-CN.md) guides for translated setup instructions, and [TRANSLATING.md](TRANSLATING.md) to contribute a correction.

## Printing from Chrome / marketplaces

Choose the new printer, your roll's paper size, one page per sheet and one copy for the first check. Fit a label PDF to the printable area only when its source size differs from your roll; if it already matches, preserve its physical size. Disable browser headers/footers when printing HTML. An A4 sheet containing many labels is not automatically split into individual label pages—export individual labels from the source service first.

For a PDF/image with the wrong orientation, open it in Open Xprinter, select your stock and enable **Rotate source 90°** when the preview needs it. Matching-size PDFs are preserved; larger pages are fitted with a safe margin.

## Changing USB ports or rolls

If the app reports that the port changed or the queue is paused, click **Install / repair USB driver** in its settings. Repairs reconnect only this project's queue and retain its saved media defaults. When changing rolls, update the size and gap/mark setting and save the new defaults. **Align label start** feeds to the next label origin; the driver performs this automatically before each gap/mark print job.

See [troubleshooting](TROUBLESHOOTING.md) if the first label is still wrong.

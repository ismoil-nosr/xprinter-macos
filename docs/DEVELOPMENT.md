# Development and releases

## Architecture

`src/filter/rastertoxp330b.c` implements the standard CUPS filter arguments: job id, user, title, copies, options and optional raster filename. It uses the [CUPS raster API](https://openprinting.github.io/cups/doc/api-raster.html), rather than decoding CUPS headers itself. Standard input and filename input are supported. No job titles or user names are emitted to the printer or logs.

`scripts/generate-ppd.py` creates this project's PPD from scratch using standard [CUPS PPD extensions](https://openprinting.github.io/cups/doc/spec-ppd.html). It fixes 203 dpi and monochrome raster output, and uses standard metric media identifiers with the appropriate physical PaperDimension. The identifier `40x58mmRotated.Fullbleed` describes our 58 mm across-head × 40 mm feed paper; its `PaperDimension` remains 164.40945 × 113.38583 points. The `Rotated` name is a macOS paper identifier, not an instruction to rotate every PDF.

The filter validates raster sizes, resolution, color layout, stride and copies before allocation. Each page is buffered before its commands are sent, so an incomplete page cannot leave the printer waiting for a partial bitmap. It accepts chunked 1/8-bit gray or black and 24-bit RGB/sRGB, rejects unsupported layouts, limits a bitmap to 609×7993 dots and a row to 4096 bytes, and supports cancellation and output errors. Blank padding bits remain white. If a later page is malformed, earlier complete pages may already have printed; inspect the queue before retrying a partial job.

The TSPL sequence is SIZE, GAP/BLINE, reference/direction, speed/darkness, direct thermal and tear-off settings, HOME (only for the first gap/mark page), CLS, BITMAP mode 0 and PRINT. Raster header NumCopies wins over command-line copies to avoid multiplying RIP-expanded copies. The printer may consume one blank label when finding its origin. This release deliberately omits unverified GAPDETECT/BLINEDETECT commands.

The Swift app uses native AppKit, SwiftUI, Core Image, PDFKit and Vision. Files and printing stay local; there is no telemetry or updater. The setup helper installed by the package is root-owned; the app uses a normal macOS authorization dialog to invoke its fixed path. It does not execute an administrator script from a downloaded/user-writable app bundle. External commands receive argument arrays or strictly quoted, validated setup arguments; the app never stores administrator passwords.

Setup owns only queue `XP330B_OpenSource`. It discovers USB locations on each setup/repair, refuses unknown device URIs and conflicting queue ownership, preserves defaults on a repair, and waits for the user to handle pending jobs before reconfiguration. Installation with no device succeeds and defers queue creation. No global printer default, sharing service, launch daemon, root cron job, relaxed permissions or CUPS restart is configured.

## Building

Use Xcode/Command Line Tools with a macOS SDK that can target macOS 14, plus Python 3 at build time. Run `./scripts/build.sh` then `./scripts/test.sh`. `build/` and `dist/` are ignored; source fixtures are generated during tests. ShellCheck is used when present; maintainers should run it before submitting shell changes. Runtime users do not need developer tools or Python.

Change `VERSION`, the filter version string and PPD FileVersion together when releasing. Every release is built from a tag matching VERSION, and its CI tests run natively on Apple Silicon and Intel. Architecture slices are also validated inside the expanded package. Automated tests do not replace physical printer testing.

## Signed releases

The first release is unsigned, as explicitly chosen by the maintainer. A future release without unidentified-developer approval requires an Apple Developer Program account, [Developer ID Application and Developer ID Installer certificates](https://developer.apple.com/help/account/certificates/create-developer-id-certificates/), and notarization.

Import certificates into the local keychain using Apple's tooling. Do not commit certificates, private keys, account passwords or notarization credentials. Supply signing identity names to the build:

```sh
APPLICATION_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
INSTALLER_SIGNING_IDENTITY='Developer ID Installer: Your Name (TEAMID)' \
./scripts/build.sh
./scripts/test.sh
./scripts/notarize.sh dist/Open-Xprinter-0.1.0-universal-signed.pkg YOUR_KEYCHAIN_PROFILE
```

Configure the profile with Apple's `notarytool store-credentials` interactively according to [Apple's notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). The notarization helper submits the signed package, staples the result and assesses it. A successful build alone does not establish successful notarization.

The default GitHub release workflow publishes an **unsigned** artifact and states that explicitly. Do not rename it “signed” or “notarized”; add a separately reviewed signing workflow if CI signing is introduced.

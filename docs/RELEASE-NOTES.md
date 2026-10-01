First public release of Open Xprinter: an independent MIT-licensed XP-330B USB driver, universal macOS app and offline Installer package.

- Intel and Apple Silicon, macOS 14 or newer.
- Correct physical label dimensions and label-start alignment with HOME for gap/mark stock.
- Code 128, QR, Unicode text, PDF/image import and CSV batches.
- USB discovery, setup without a connected printer, saved media defaults, repair and scoped uninstall.
- Automated native Mac tests, CUPS PDF pipeline checks, final bitmap barcode decoding and package installation/reinstallation checks.

**This first release is unsigned by Apple and is not notarized.** Approve the specific installer and, if needed, the app through macOS Privacy & Security. No security protection needs to be disabled. See the repository's English/Russian installation instructions.

Only XP-330B USB/TSPL is supported. Other models, network/Bluetooth, black-mark firmware variations and every possible roll are not hardware-certified. Match the loaded label size and gap, print and scan one label before a batch, and read `docs/VALIDATION.md` for the hardware evidence.

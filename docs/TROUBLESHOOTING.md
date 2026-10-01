# Troubleshooting

## Nothing prints / USB not detected

Turn on the printer, close its cover, check that it has paper, and try another cable or direct USB connection. USB power alone does not prove the cable carries data. Refresh in Open Xprinter. This release detects XP-330B USB identity only; it does not claim compatibility with unknown models.

When macOS changes the USB location after moving a cable, use **Install / repair USB driver**. Finish or cancel outstanding jobs in Print Center before reconfiguring. The app does not cancel your jobs automatically.

## QR code crosses a gap or labels are skipped

Check these in order:

1. Measure one label's width across the head and height along the feed. Measure the gap separately.
2. Match the paper size in the app and the print dialog. 58×40 and 40×58 are different feed lengths.
3. Select gap labels, black marks or continuous roll to match the media. Gap/mark stock requires a positive gap/mark height.
4. Close the cover and use **Align label start**; print one label.
5. If plain FEED from the printer itself does not reliably advance one label, the sensor, roll loading, printer mode or hardware calibration needs attention. Follow the XP-330B manual for your firmware; keep media under the sensor and clean it according to the manufacturer. The app's alignment button is not a replacement for hardware sensor calibration.

The driver emits HOME once per gap/mark job after SIZE and GAP/BLINE. HOME finds the origin; it cannot compensate for incorrect dimensions or a sensor that does not detect the media.

## Blank, inverted or mirrored output

Confirm that the roll is direct thermal stock and its printable side faces the head. The driver uses 203 dpi, direct thermal mode and TSPL bitmap mode 0, with white bits set and black bits cleared. If your firmware interprets this differently, open a hardware report instead of enabling random generic printer modes. It has no ESC/POS receipt-mode support.

## Barcode will not scan

Print at the correct stock size, start with darkness 7 and speed 3, and preserve the white quiet area around the code. Excessive darkness spreads bars. Too little darkness breaks them. The app rejects generated codes with fewer than two printer dots per module. Imported PDFs can contain codes that are already too dense; software cannot restore missing detail.

## CUPS says “completed” but the physical result is wrong

CUPS completion confirms that the backend sent a job. It does not measure label alignment or scan a barcode. Inspect and scan the first physical label before a batch. Include your macOS version, CPU, firmware if known, loaded stock dimensions, gap/mark size, app settings and a non-sensitive example in a GitHub issue. Do not post private order labels, USB serial numbers or account credentials.

## Installer warning

The first release is intentionally unsigned by Apple. Approve the specific installer/app using the normal macOS flow described in [installation](INSTALL.md). Do not disable Gatekeeper, SIP, change all print-file permissions, or install a root cron job. None of those steps is required by this project.

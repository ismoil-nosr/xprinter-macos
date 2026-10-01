# Validation record

Initial development: October 2026. Hardware evidence is separate from tests that do not use a printer.

## Automated checks

`scripts/test.sh` exercises native CUPS raster fixtures across supported color modes and row padding, label origin alignment, continuous/mark commands, NumCopies, multiple pages, stdin/file equivalence, invalid settings, malformed streams and maximum bounds. It rasterizes generated PDFs through Apple's CUPS PDF pipeline and decodes Code 128, QR and Unicode QR from the final TSPL bitmap with Vision. Installer contents are expanded and checked for both CPU slices, signatures, permissions, resources and paths.

GitHub Actions runs builds and these tests on macOS 14 Apple Silicon, macOS 15 Intel and macOS 26 Apple Silicon. It then installs and reinstalls the package on the runner with no USB printer, verifies installed files/permissions and removes only the project's installation. The workflow status is the authority for a given commit; a configured workflow is not evidence that it has passed.

Version 0.2.0 adds translation coverage and printf argument checks for all three catalogs, bundled-resource and installer-page checks, runtime language/error/number formatting and fallback checks, and language-switch tests using an isolated preference domain. Those tests verify that Unicode label content, physical dimensions, stock identifiers, gap, darkness and copies remain unchanged. A Chinese QR fixture is also decoded after the complete CUPS-to-TSPL pipeline.

On the development Mac, the native app was switched through Simplified Chinese, Russian and English. The UI and menu bar changed immediately; status, help and validation messages were checked, while the 58×40 mm size, 2 mm gap and barcode value remained intact. No new hardware print is needed to verify an interface-only change; the physical evidence below concerns the driver baseline.

## Physical validation

| Configuration | Evidence |
| --- | --- |
| XP-330B, USB, Apple Silicon, macOS 26.5, 58×40 mm gap stock | The label-start fix using HOME after SIZE/GAP was physically confirmed: the full QR and both text lines stayed on one label. That first confirmation used the vendor rasterizer with an independently written alignment wrapper. |
| Independent open source filter, same printer/roll | Installed from this project's universal .pkg. A generated 58×40 mm label with a QR, product title and numeric caption printed wholly on one label; the operator confirmed no gap split or unwanted skipped label. The new queue completed the job and returned idle. |
| Intel Mac with physical printer | Not physically tested; native CI tests do not attach a printer. |
| Black marks, continuous rolls, different firmware/stock | Command generation tested; no physical compatibility claim for every variant. |

Submit additional reports with model/firmware, macOS version, CPU, USB connection, label dimensions, gap/mark measurements and a non-sensitive sample. Do not upload real customer/order labels or USB serials.

# Validation record

Initial development: October 2026. Hardware evidence is separate from tests that do not use a printer.

## Automated checks

`scripts/test.sh` exercises native CUPS raster fixtures across supported color modes and row padding, absence of extra feeds across separate and multi-page jobs, continuous/mark commands, NumCopies, multiple pages, stdin/file equivalence, invalid settings, malformed streams and maximum bounds. It rasterizes generated PDFs through Apple's CUPS PDF pipeline and decodes Code 128, QR and Unicode QR from the final TSPL bitmap with Vision. Installer contents are expanded and checked for both CPU slices, signatures, permissions, resources and paths.

GitHub Actions runs builds and these tests on macOS 14 Apple Silicon, macOS 15 Intel and macOS 26 Apple Silicon. It then installs and reinstalls the package on the runner with no USB printer, verifies installed files/permissions and removes only the project's installation. The workflow status is the authority for a given commit; a configured workflow is not evidence that it has passed.

Version 0.2.0 adds translation coverage and printf argument checks for all three catalogs, bundled-resource and installer-page checks, runtime language/error/number formatting and fallback checks, and language-switch tests using an isolated preference domain. Those tests verify that Unicode label content, physical dimensions, stock identifiers, gap, darkness and copies remain unchanged. A Chinese QR fixture is also decoded after the complete CUPS-to-TSPL pipeline.

On the development Mac, the native app was switched through Simplified Chinese, Russian and English. The UI and menu bar changed immediately; status, help and validation messages were checked, while the 58×40 mm size, 2 mm gap and barcode value remained intact. No new hardware print is needed to verify an interface-only change; the physical evidence below concerns the driver baseline.

Version 0.3.0 adds the headless renderer used by the separate MCP server. Automated checks validate 58×40 mm PDF geometry, 464×320 preview pixels at 203 dpi, two-page Chinese QR labels, PDF reimport, Code 128 decoding, streamed input and invalid requests. This change does not alter label alignment or the raster-to-TSPL commands. MCP protocol, OAuth and retry tests live in [xprinter-mcp](https://github.com/ismoil-nosr/xprinter-mcp). No additional physical print is claimed for this integration.

## Physical validation

| Configuration | Evidence |
| --- | --- |
| XP-330B, USB, Apple Silicon, macOS 26.5, 58×40 mm gap stock | The label-start fix using HOME after SIZE/GAP was physically confirmed: the full QR and both text lines stayed on one label. That first confirmation used the vendor rasterizer with an independently written alignment wrapper. |
| Independent open source filter, same printer/roll | Installed from this project's universal .pkg. A generated 58×40 mm label with a QR, product title and numeric caption printed wholly on one label; the operator confirmed no gap split or unwanted skipped label. The new queue completed the job and returned idle. |
| Intel Mac with physical printer | Not physically tested; native CI tests do not attach a printer. |
| Black marks, continuous rolls, different firmware/stock | Command generation tested; no physical compatibility claim for every variant. |

Submit additional reports with model/firmware, macOS version, CPU, USB connection, label dimensions, gap/mark measurements and a non-sensitive sample. Do not upload real customer/order labels or USB serials.

## Security maintenance (0.3.1)

Local checks passed on 2026-10-01: early CSV rejection at record 501 and expanded quantity 501, field-byte/column/input limits, BOM/CRLF/quoted multiline Chinese/Russian data, nonlocal URL rejection, and an independent 25-second native deadline with stdin deliberately left open. Barcode decoding through the CUPS-to-TSPL pipeline, all three translation catalogs and the universal package layout/signatures/permissions also passed. No new physical print was sent.

Named CUPS raster inputs reject symlinks, FIFOs without writers, directories and devices without printer output or blocking. Normal file/stdin raster jobs still produce identical bytes. Security gate regressions cover SARIF driver/extension rules, high/critical thresholds, unresolved metadata, exact reviewed locations and invalidated/expired source-bound triage.

The app/filter depend on macOS frameworks and system libcups; current system-parser advisories and OS patch state cannot be certified by this repository's checks. CI adds CodeQL and release gates; see the [security policy](../SECURITY.md).

## Blank-label feed correction (0.3.2)

On 2026-10-06 the operator reported a blank label skipped before each separate Chrome job on the historical `XP330B_USB` queue, while 58×40 mm geometry and printed artwork remained correct. Inspection found automatic HOME insertion in both that queue's wrapper and the open source filter. Version 0.3.2 removes automatic HOME from normal printing and retains the app's explicit alignment operation. Automated checks cover successive independent jobs, multi-page jobs and unchanged barcode/QR decoding. Physical confirmation of successive jobs is still pending; earlier one-label confirmations do not prove this behavior.

# Security policy

Open Xprinter is a normal-user macOS app and render-only command-line bridge, plus a system CUPS filter. Installing, repairing or removing the driver requires macOS administrator authorization. Printing consumes physical labels; only grant printer access to people and AI accounts you trust.

## Enforced boundaries

- Installer and privileged helpers operate on the fixed project queue and named installed files. Setup validates the USB model, options and driver ownership; it refuses pending jobs and unrelated drivers. The GUI invokes only the root-installed setup helper through the macOS administrator dialog.
- GUI commands use argument arrays and the local CUPS socket. Imported content cannot select a shell command, administrator helper or queue. Import accepts regular local files, not web URLs or named pipes.
- CSV import reads at most 4 MiB, retains one field/row at a time, caps fields at 4,096 UTF-8 bytes and rows at 16 columns, and stops immediately above 500 expanded labels. Quoted commas/newlines, escaped quotes, CRLF, BOM and multilingual text remain supported.
- CUPS filter validates resolution, geometry, stride, pixel formats, copies and page count before owned allocation. It buffers complete pages and emits fixed numeric/enum TSPL with exact bitmap framing.
- Temporary documents use unique private directories. The headless bridge has bounded stdin/PDF/page/pixel/output sizes and an independent 25-second deadline, including while waiting for stdin. It never installs a driver, changes preferences or submits a job.
- CI runs native regression/package checks and CodeQL for the production C/Swift code, Python and workflows. High/critical CodeQL findings block releases. The gate tests both SARIF driver and extension rule metadata and fails on unresolved rules. Any future false-positive exception must identify an exact location, expire and bind reviewed source hashes. PR dependency review and weekly Dependabot action updates complement weekly CodeQL scans. Actions are commit-pinned and checkout credentials are not persisted.

## Dependencies and limits

The app/filter use Apple system frameworks and system libcups. There is no bundled third-party Swift/Python package graph to audit with npm. Keep macOS and its security updates current; static source review cannot establish the safety of Apple's PDF/image/CUPS parsers. Imported PDF/image parsing is not isolated by an operating-system sandbox. Resource limits and deadlines do not make arbitrary hostile documents safe.

The ordinary OS account already has access to its app files, queue and private documents. The separate [MCP service](https://github.com/ismoil-nosr/xprinter-mcp) owns network authentication, scopes, owner isolation, print quotas and retry receipts. Other apps printing directly bypass MCP quotas. Spool retention, filesystem snapshots, backups and temporary files left by a killed process are controlled by the OS/operator.

The initial public packages are **unsigned by Apple**, with ad-hoc executable signatures, and are **not notarized**. Ad-hoc signatures/checksums detect corruption but do not authenticate an Apple Developer ID. Developer ID signing and notarization require the maintainer's Apple account/certificates; do not disable Gatekeeper globally. See [installation](docs/INSTALL.md).

## Reporting

Use [GitHub private vulnerability reporting](https://github.com/ismoil-nosr/xprinter-macos/security/advisories/new). Do not post passwords, SSH keys, tokens, USB serials, customer labels or exploitable private details in public issues. Include the affected version, OS and a minimal non-sensitive reproducer. Security fixes require a regression test. Currently maintained: the latest released version.

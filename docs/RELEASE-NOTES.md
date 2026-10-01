# Open Xprinter 0.3.1

- Fix a low-severity CSV import resource-consumption issue (CWE-400): validate records as they arrive instead of allocating all rows before the 500-label limit.
- CSV limits: 4 MiB input, 4,096 UTF-8 bytes per field, 16 columns, 500 expanded labels. Preserve multilingual text, quoting, BOM and CRLF. New errors are available in English, Russian and Simplified Chinese.
- Import regular local files only; use the local CUPS socket for GUI commands.
- Restrict named CUPS raster inputs to regular files; reject symlinks, FIFOs, directories and devices without hanging. Preserve normal stdin/spool-file printing.
- Headless MCP rendering now has its own 25-second deadline, including when stdin stays open or an SSH client disconnects. Upgrade to this version for MCP 0.2.1.
- Add CodeQL for C, Swift, Python and Actions, PR dependency review, weekly scanning and Dependabot action updates. High/critical source findings block release.
- Native build, localization, package, barcode-through-TSPL and new parser/deadline regressions pass without sending a job to a physical printer. Existing print geometry and raster commands are unchanged.

The universal installer supports Apple Silicon and Intel on macOS 14+. It remains **unsigned by Apple and not notarized**, with ad-hoc-signed executables. See [installation](INSTALL.md) and [security policy](../SECURITY.md).

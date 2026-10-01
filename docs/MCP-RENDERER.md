# Headless renderer contract

Available in Open Xprinter 0.3.0+. The optional MCP server is maintained in [ismoil-nosr/xprinter-mcp](https://github.com/ismoil-nosr/xprinter-mcp), with its own releases. Keeping the integration small lets the native app remain independent of Node and lets future printer backends evolve outside this driver repository.

Run the installed executable with `--mcp-render`. It reads one JSON object from stdin until EOF, returns one JSON object on stdout and exits. It does not launch the GUI, change saved preferences, install a driver, configure CUPS or move paper.

```json
{
  "widthMm": 58,
  "heightMm": 40,
  "labels": [{"kind": "qr", "title": "商品 · Товар", "code": "TEST-123", "footer": "¥25", "quantity": 1}]
}
```

Alternatively supply `pdfBase64` and optional `rotate: true` instead of `labels`. Local paths and remote URLs are not part of this API. The native renderer preserves PDF aspect ratio; same-size PDFs keep their original physical bounds. It does not split an A4 sheet containing several labels into individual labels.

Success returns `pdfBase64`, `previewBase64` (PNG of page 1 at 203 dpi), `pages`, `widthMm`, and `heightMm`. Exit 1 returns `{"error":"…"}`. Bridge diagnostics use English; the MCP server localizes tool titles/descriptions. The GUI retains its three-language interface.

Bounds: 3 MiB JSON input; 20–76 mm across the roll; 10–200 mm along feed; 1–50 records; at most 100 expanded pages; QR content 800 UTF-8 bytes; Code 128 up to 80 printable ASCII characters. PDFs must be unencrypted, at most 2 MiB and 100 pages. Output PDF is limited to 6 MiB and the batch to 40 million printer pixels. Split larger batches. The MCP caller imposes a process timeout and its own validated schemas/quotas. These bounds reduce resource use; they are not an operating-system sandbox for PDF parsing.

The JSON bridge delegates label drawing and import fitting to `LabelRenderer`. CUPS media settings, user authorization, retry receipts and print submission belong to the separate MCP service. Do not invoke this flag on an older installation: inspect `CFBundleShortVersionString` first; versions before 0.3.0 have no headless entry point.

`tests/VerifyMCP.swift` exercises streamed JSON input, physical PDF dimensions, preview dot dimensions, Chinese QR/Code 128 decoding, PDF reimport and invalid requests. The standard build/test workflow includes it on ARM and Intel Macs. It consumes no labels.

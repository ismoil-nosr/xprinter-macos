Open Xprinter 0.3.0 adds a headless label renderer for the separate open-source [MCP server](https://github.com/ismoil-nosr/xprinter-mcp).

- AI clients on macOS, Windows and Linux can connect to the Mac printer server through MCP. The optional Node component is installed separately; this driver installer does not open a network port or add Node.
- The bounded stdin/stdout JSON bridge reuses the native GUI's Code 128, Unicode QR, text and PDF fitting implementation. It returns a physical-size PDF and first-page preview without moving paper or changing preferences.
- New tests cover physical dimensions, Chinese QR and Code 128 decoding, PDF reimport, streamed input and invalid requests.
- English, Russian and Simplified Chinese GUI; macOS 14+, universal Intel / Apple Silicon installer; XP-330B USB / TSPL.

**This package remains unsigned by Apple and is not notarized.** Approve it through macOS Privacy & Security as described in the [installation guide](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/INSTALL.md). No system protections need to be disabled.

Русский: добавлен генератор этикеток для отдельного [MCP-сервера](https://github.com/ismoil-nosr/xprinter-mcp). Обычная печать и интерфейс на трёх языках сохраняются; MCP устанавливается отдельно.

简体中文：新增用于独立 [MCP 服务器](https://github.com/ismoil-nosr/xprinter-mcp) 的无界面标签生成接口。普通打印和三语言界面保持不变；MCP 为单独安装的可选组件。

The driver baseline was physically confirmed on 58×40 mm gap stock. This release's integration checks do not claim an additional physical print or universal firmware compatibility. See [validation](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/VALIDATION.md).

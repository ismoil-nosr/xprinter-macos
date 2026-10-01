Open Xprinter 0.2.0 adds English, Russian and Simplified Chinese to the native macOS label app.

- Switch languages instantly from the top-right menu; your choice is remembered for next launch.
- Translated menus, printer status, setup/print prompts, help and app validation errors. Label content, physical size and printer settings remain unchanged.
- Localized installer welcome/conclusion pages, complete Chinese usage and contribution guides, a Chinese CSV example, and a translation guide.
- Tests for all translation keys, format arguments, language fallback, runtime errors and preservation of label content/settings while switching. Chinese QR data is checked after the complete CUPS-to-TSPL pipeline.
- Universal Intel / Apple Silicon installer, macOS 14+, XP-330B USB / TSPL.

**The package remains unsigned by Apple and is not notarized.** Approve this installer and, if needed, the app through macOS Privacy & Security. No system protections need to be disabled. See the [installation instructions](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/INSTALL.md).

Русский: интерфейс, меню, помощь и ошибки переведены на русский. Выберите «Русский» справа вверху; этикетки и настройки сохранятся. [Инструкция](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/README.ru.md).

简体中文：应用界面、菜单、帮助和错误提示已支持中文。右上角选择“简体中文”即可即时切换，标签内容和打印参数保持不变。欢迎用中文提交 Issue 或 Pull Request。[中文使用指南](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/README.zh-CN.md) · [中文贡献指南](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/CONTRIBUTING.zh-CN.md)。

Match the loaded label size and gap, then print and scan one label before a batch. Hardware coverage is recorded in [VALIDATION.md](https://github.com/ismoil-nosr/xprinter-macos/blob/main/docs/VALIDATION.md).

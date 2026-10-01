# Contributing

[English](CONTRIBUTING.md) · [中文贡献指南](docs/CONTRIBUTING.zh-CN.md) · [Translation guide / Переводы / 翻译](docs/TRANSLATING.md)

Contributions and hardware reports are welcome. Keep the XP-330B USB scope clear and document evidence before adding another model or transport.

Issues and pull requests in English, Russian or Chinese are welcome; you do not need to translate your report into English before contributing. Chinese users can start with the [中文使用指南](docs/README.zh-CN.md), [中文贡献指南](docs/CONTRIBUTING.zh-CN.md) and UTF-8 [CSV example](examples/labels.zh-CN.csv).

For interface text, add the same English key to all three `Localizable.strings` catalogs and preserve format argument types/order. Run the build and test scripts; translation checks also run on CI. See [TRANSLATING.md](docs/TRANSLATING.md) before changing localized option labels or introducing another language.

For a code change, explain the user-visible problem and expected result, run the build and test scripts on macOS, and include a hardware check when the change affects paper movement, bitmap format or media dimensions. Add a behavior test for a bug fix. Keep synthetic fixture data and examples free of account details, order identifiers and proprietary SDK content.

Use the CUPS raster API, validate new options and input bounds, keep pixel padding white, and avoid shell execution inside the filter. Installer changes must preserve other queues and remain usable without a connected device. Respect the installed root-owned helper boundary; do not fix permissions with chmod 777 or weaken macOS security.

Project contributions are made under the MIT license. Do not copy vendor binaries, PPDs, SDK source or manuals into this repository without an explicit redistribution license. Link to official documents when discussing protocol behavior.

For help, use GitHub Issues with a minimal, non-sensitive reproduction. For a security issue involving unsafe administrator execution or a buffer error, prefer GitHub's private vulnerability reporting when available; do not include credentials or private print content in public reports.

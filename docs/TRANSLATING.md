# Translating Open Xprinter

[English usage](../README.md) · [Русский](README.ru.md) · [简体中文](README.zh-CN.md)

The app supports English (`en`), Russian (`ru`) and Simplified Chinese (`zh-Hans`). Choose a language from the top-right menu; it takes effect immediately and is saved only in this app's preferences. System default follows the first supported preferred macOS language; Chinese locales use Simplified Chinese. Unsupported preferred languages fall back to English. System-owned authorization dialogs and some file panel controls follow macOS's language.

## Files and rules

Translations are native UTF-8 `Localizable.strings` files in `src/app/Resources/<language>.lproj/`. The left-hand English text is the stable key; translate only the right-hand value. All three catalogs must have exactly the same keys. Keep `%d` (integer) and `%@` (string) arguments in the same order and with the same type. Use a neutral count label instead of assuming English plural rules.

```text
"Label size" = "标签尺寸";
"Copies: %d" = "份数：%d";
```

Escape quotes and backslashes using `\"` and `\\`. Use actual UTF-8 characters. Brand names, CSV column names and type values, CUPS queue/media identifiers, TSPL commands and stored option values remain stable across languages. Never translate user-entered or imported label content.

Installer welcome/conclusion pages are in `packaging/ru.lproj/` and `packaging/zh-Hans.lproj/`; English pages are `packaging/welcome.html` and `packaging/conclusion.html`. Installer selects these from the system language. Update the corresponding usage document when button labels or setup instructions change.

For new UI text, call `L("English key")`; for numbers or inserted text use `LF("Copies: %d", copies)`. Add translations to every catalog. Dynamic status/menu keys must also be covered by `tests/test_localization.py`. The app uses [Foundation Bundle localization](https://developer.apple.com/documentation/foundation/bundle/localizedstring(forkey:value:table:)) and declares [CFBundleLocalizations](https://developer.apple.com/documentation/bundleresources/information-property-list/cfbundlelocalizations). Do not change global `AppleLanguages` or force a printer option to use the translated display label.

Run `./scripts/build.sh` and `./scripts/test.sh`. Tests check key coverage, duplicate keys, format argument safety, packaged resources, runtime translations, language fallback, localized errors, and preservation of label content, paper settings and PDF dimensions during switching. Also open the app, switch through all three languages, check the menu bar, help and validation messages, and restart to confirm the selection persists. This does not require a printer or sending a print job.

## Русский: исправление перевода

Редактируйте правую часть строк в `src/app/Resources/ru.lproj/Localizable.strings`. Английские ключи, `%d` и `%@`, названия столбцов CSV и внутренние значения настроек сохраняйте. Проверяйте длинные подписи в окне приложения и соответствие инструкции [на русском](README.ru.md). Переключение языка не должно менять текст этикетки, размер, тип бумаги и зазор.

## 简体中文翻译说明

编辑 `src/app/Resources/zh-Hans.lproj/Localizable.strings` 的右侧中文，保持左侧英文键不变。保留 `%d` 和 `%@` 的数量、顺序和类型；不要翻译 CSV 列名、`code128` / `qr` / `text`、队列名、TSPL 命令或内部纸张选项值。

新增界面文本时，请同时更新英文、俄文和简体中文文件。修改安装器文案时，更新 `packaging/zh-Hans.lproj/` 和[中文使用指南](README.zh-CN.md)。运行构建与测试，再实际切换三种语言，检查按钮、菜单、帮助和错误信息是否完整，重启后语言是否保留。切换语言不得修改标签内容和打印参数。欢迎直接用中文提交贡献。

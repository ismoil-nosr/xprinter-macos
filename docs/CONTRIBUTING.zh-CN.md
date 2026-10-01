# 贡献指南

[English](../CONTRIBUTING.md) · [中文使用指南](README.zh-CN.md)

欢迎使用中文提交 Issue、Pull Request、翻译改进及实机测试报告。报告问题时请说明预期结果、实际结果和最小复现步骤；无需先把内容翻译成英文。

## 开发环境

需要 macOS 14 及以上、Xcode 或 Command Line Tools 和 Python 3。构建依赖 Apple 自带的 CUPS 和系统框架，不需要第三方驱动或 Rosetta：

```sh
git clone https://github.com/ismoil-nosr/xprinter-macos.git
cd xprinter-macos
./scripts/build.sh
./scripts/test.sh
```

无打印机也能执行自动测试。`tests/test_installation.sh` 用于全新 CI 环境，包含安装和卸载操作；日常开发请先运行 `scripts/test.sh`。

## 代码结构

| 路径 | 内容 |
| --- | --- |
| `src/filter/rastertoxp330b.c` | CUPS 光栅到 TSPL 转换；纸张尺寸、像素、进纸控制 |
| `src/app/LabelRenderer.swift` | 按物理尺寸生成标签、Code 128 / QR、导入 PDF / 图片 / CSV |
| `src/app/XprinterLabels.swift` | 原生 SwiftUI 界面、打印队列和 USB 设置 |
| `src/app/Localization.swift` | 应用语言选择、资源加载、数字格式及系统语言回退 |
| `src/app/Resources/*.lproj/Localizable.strings` | 英文、俄文和简体中文翻译 |
| `driver/`、`scripts/`、`packaging/` | PPD、构建、安装、修复及卸载 |
| `tests/` | 光栅、扫码、翻译、安装包和设置行为测试 |

## 提交要求

- 说明用户遇到的问题及修改后的行为，运行构建和测试，并附上结果。
- 修复应包含验证实际行为的测试。涉及进纸、位图格式或尺寸时，尽可能附实机确认。
- 目前支持范围是 XP-330B USB / TSPL。扩展其他型号或连接方式前，请提供协议依据和设备测试证据。
- 保持输入边界检查和白色像素填充；驱动内不要执行 shell 命令。管理员辅助脚本必须由 root 拥有，不能使用 `chmod 777` 或降低 macOS 安全保护。
- 安装器必须保留其他打印机和队列，且在打印机未连接时仍能完成安装。
- 只使用合成样例或去除敏感信息的测试内容。不得上传真实客户标签、订单号、USB 序列号或凭据。
- 贡献采用 MIT 许可证。没有明确再分发许可时，不要复制厂商驱动、PPD、SDK 源码或手册到仓库。

## 翻译

可直接编辑 `src/app/Resources/zh-Hans.lproj/Localizable.strings`。左侧英文键保持不变，只修改右侧中文。必须保留 `%d`、`%@` 参数的数量、类型及顺序，不能翻译 CSV 列名、队列名、打印协议或内部选项值。完整流程见[翻译指南](TRANSLATING.md#简体中文翻译说明)。

## 实机报告

请注明打印机型号 / 固件、macOS 版本、CPU、USB 连接方式、标签宽度与进纸高度、间隙 / 黑标高度，以及是否能够在一张标签内打印完整内容并扫码。可以附不含个人信息的照片。

涉及管理员执行或内存错误的安全问题，请优先使用 GitHub 私密漏洞报告（如果可用）。公共 Issue 不应包含凭据或私密打印内容。

# Open Xprinter：macOS 开源标签打印方案

[English](../README.md) · [Русский](README.ru.md) · **简体中文**

用于 **Xprinter 芯烨 XP-330B** 的 USB 标签打印驱动和原生 Mac 应用。一个离线安装包同时支持 **Apple Silicon 和 Intel，macOS 14 及以上**。驱动、应用和安装脚本均使用 MIT 许可证；不包含厂商的闭源驱动或 SDK。

[下载最新安装包](https://github.com/ismoil-nosr/xprinter-macos/releases/latest) · [中文贡献指南](CONTRIBUTING.zh-CN.md) · [报告问题](https://github.com/ismoil-nosr/xprinter-macos/issues)

## 安装与首次使用

1. 从本仓库的 Releases 下载 `.pkg`，打开并完成安装。当前安装包**没有 Apple Developer ID 签名，也未经过 Apple 公证**。如果 macOS 阻止打开，请先尝试打开一次，再进入 **系统设置 → 隐私与安全性 → 仍要打开**，仅批准这个安装包。应用若另被阻止，可用同样方法批准。无需关闭 Gatekeeper 或 SIP。
2. 通过 USB 连接 XP-330B，开机，装入直接热敏标签纸并合上盖子。打印机需要处于 TSPL 标签模式。也可以先安装软件，再连接打印机。
3. 在“应用程序”中打开 **Open Xprinter**。右上角语言菜单可选择 **简体中文**、**English**、**Русский** 或 **跟随系统**。切换即时生效，并会在下次启动时保留；不会修改标签内容和打印机设置。
4. 如需要，点击 **设置打印机**，确认 macOS 管理员授权。如果连接了多台 XP-330B，请先选择要使用的 USB 设备。
5. 选择实际装入的标签尺寸、纸张类型以及间隙或黑标高度。**58 × 40 毫米**表示打印头横向宽度为 58 毫米，进纸方向高度为 40 毫米。纸张间隙单独测量，不包含在 40 毫米内。初始间隙为 2 毫米，请按实际纸张调整。
6. 点击 **保存为其他应用的默认设置…**，让 Chrome、“预览”等应用也使用这些纸张参数。其他应用仍可覆盖默认设置，因此打印前请核对页面尺寸。
7. 先打印一张，确认二维码和文字完全位于同一张标签内，并扫描条码确认可读，再进行批量打印。

安装包会保留已有打印机和系统默认打印机。本项目创建的队列为 `XP330B_OpenSource`，在其他应用中显示为 **Xprinter XP-330B Labels (Open Source)**。打印无需 Rosetta、Homebrew、Python 或网络；Python 仅用于开发和构建。

## 语言与标签内容

应用界面、菜单、操作提示和应用自身的错误信息支持英文、俄文和简体中文。“跟随系统”会选择支持的系统首选语言；不匹配时使用英文。中文系统语言使用简体中文界面。macOS 自身的授权窗口和部分文件选择控件仍使用系统语言。

语言切换只影响界面。标签上的商品名称、价格、条码内容、导入文件和尺寸不会被翻译或更改。**Code 128 只支持可打印的 ASCII 字符；中文、俄文等 Unicode 内容请使用二维码或纯文本标签。**

## 从 Chrome、平台或“预览”打印

选择 **Xprinter XP-330B Labels (Open Source)**，纸张尺寸与实际标签一致，每张纸一页，首次仅打印一份。如果 PDF 本来就是标签尺寸，请保持其实际尺寸；只有源页面大小不匹配时才缩放适应，并确认条码仍可识别。打印网页时关闭浏览器页眉和页脚。

包含多张标签的 A4 页面不会自动被拆分成独立标签，请从来源平台导出逐页标签。PDF 或图片方向不正确时，可在 Open Xprinter 中打开，勾选 **将源文件旋转 90°**，并核对预览。

## 中文 CSV 批量打印

CSV 使用 UTF-8 编码。列名和 `type` 值是固定格式，不随界面语言改变：

```csv
title,code,footer,type,quantity
商品示例,12345678,¥25,code128,1
中文二维码,中文测试-123,请扫描,qr,1
文字标签,欢迎使用 Open Xprinter,,text,1
```

必填列为 `code`；可选列为 `title`、`footer`、`type`、`quantity`。`type` 可选 `code128`、`qr`、`text`。每行数量为 1–100，总标签数最多为 500。文件最大 32 MB。可直接打开 [中文示例](../examples/labels.zh-CN.csv)，或将文件拖到预览区域。

## 跳纸、跨标签打印或换 USB 端口

驱动先发送真实尺寸和间隙 / 黑标参数，然后从当前位置打印，不会在每个任务前额外进纸。更换标签纸后，或打印内容跨越间隙时，可使用 **对齐标签起点…** 一次。此操作会发送 `HOME`，可能消耗一张空白标签；正常打印不会自动发送。页面预览正确并不代表进纸尺寸正确：如果 40 毫米长的标签被配置为进纸 58 毫米，就可能跨越间隙。

- 检查标签宽度、进纸方向高度和实际间隙 / 黑标高度，确保选中了正确纸张类型。
- 重新装纸，检查传感器是否对准间隙 / 黑标并保持清洁，再点击 **对齐标签起点…**。该操作会进纸。
- 换 USB 端口或队列暂停时，打开 **打印机设置与帮助**，点击 **安装 / 修复 USB 驱动**。
- 换标签纸后，更新尺寸和纸张参数，并保存为其他应用的默认设置。
- “已发送”表示 macOS 打印队列接受了任务；实际打印结果和扫码仍需检查。

如果问题仍存在，可[用中文提交 Issue](https://github.com/ismoil-nosr/xprinter-macos/issues)。请提供型号、固件（如已知）、macOS 版本、CPU、纸张尺寸、间隙 / 黑标高度和不含个人信息的样例。不要公开 USB 序列号、客户订单或密码。

## AI 与 MCP

独立开源的 [MCP 服务器](https://github.com/ismoil-nosr/xprinter-mcp) 支持 macOS、Windows 和 Linux 上的 AI 客户端通过统一的 MCP API 准备标签、查看预览、打印并检查自己的任务。本地使用 stdio，远程使用 SSH 或经过身份验证的 HTTPS。USB 后端运行在连接打印机的 Mac 上。

服务器 Mac 需要 Open Xprinter **0.3.0+** 和 Node 24+。MCP 是单独安装的可选组件；普通驱动安装包不会开启网络端口，也不需要 Node。[中文 MCP 指南](https://github.com/ismoil-nosr/xprinter-mcp/blob/main/docs/README.zh-CN.md)。

## 支持范围

| 项目 | 支持情况 |
| --- | --- |
| 打印机 | XP-330B，USB，TSPL 标签模式 |
| Mac | Intel / Apple Silicon，macOS 14 及以上 |
| 打印头 | 203 dpi，打印宽度最多 76 毫米 |
| 标签尺寸 | 常用毫米尺寸；自定义宽度 20–76、高度 10–1000 毫米 |
| 纸张 | 间隙标签、黑标标签、连续纸；具体固件和纸张需实机确认 |
| 界面 | English、Русский、简体中文 |
| 其他型号、蓝牙、以太网 | 当前版本不支持 |

标准 4 × 6 英寸快递标签比本打印头更宽，需要更宽的打印机。强行缩小可能让条码无法识别。本项目独立于 Xprinter / 芯烨，不代表厂商官方支持。已在 XP-330B USB、Apple Silicon、58 × 40 毫米间隙标签上完成实机确认；Intel 测试在 CI 中完成，未连接实物打印机。参见[验证记录](VALIDATION.md)。

## 构建、测试与贡献

安装 Xcode 或 Command Line Tools，并准备 Python 3。在 macOS 上运行：

```sh
git clone https://github.com/ismoil-nosr/xprinter-macos.git
cd xprinter-macos
./scripts/build.sh
./scripts/test.sh
```

通用安装包输出到 `dist/`。测试检查翻译覆盖率和格式参数、语言切换时数据保持不变、标签生成、CUPS 光栅化、最终打印位图扫码、安装包内容以及 USB 设置参数。GitHub Actions 还在全新 macOS 环境中进行安装、重复安装和卸载检查。

欢迎中文文档、翻译改进、修复和实机报告。请阅读[中文贡献指南](CONTRIBUTING.zh-CN.md)及[翻译指南](TRANSLATING.md)。MIT 贡献不得包含没有再分发许可的厂商二进制文件、PPD 或 SDK 手册。

## 卸载

关闭应用，等打印任务完成或取消后运行：

```sh
sudo /Library/Printers/OpenXprinter/uninstall.sh
```

添加 `--dry-run` 可预览操作。卸载仅移除本项目的应用、驱动、队列和安装收据，保留其他打印机、用户文档和偏好设置。

## 安全

[安全策略与私密漏洞报告](../SECURITY.md)。CSV 限制为 4 MiB、16 列、每字段 4,096 个 UTF-8 字节，以及展开数量后最多 500 张标签。0.3.1 会立即拒绝超限记录。MCP 原生渲染器具有独立的 25 秒期限；使用 MCP 0.2.1 时请升级。请及时安装 macOS 安全更新，系统 PDF、图像与 CUPS 库由 Apple 维护。安装包目前没有 Apple Developer ID 签名，也未经过公证。

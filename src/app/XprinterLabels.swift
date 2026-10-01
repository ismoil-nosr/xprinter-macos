// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ismoil Nosr
import AppKit
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import Darwin

enum Command {
    static func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("open-xprinter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        return url
    }
    static func run(_ path: String, _ arguments: [String], timeout: Double = 15) throws -> String {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let outputURL = directory.appendingPathComponent("stdout"), errorURL = directory.appendingPathComponent("stderr")
        for url in [outputURL, errorURL] {
            guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) else { throw LabelFailure.message("Could not create a temporary file.") }
        }
        let output = try FileHandle(forWritingTo: outputURL), errors = try FileHandle(forWritingTo: errorURL)
        defer { try? output.close(); try? errors.close() }
        let process = Process(), done = DispatchSemaphore(value: 0)
        process.executableURL = URL(fileURLWithPath: path); process.arguments = arguments
        process.standardOutput = output; process.standardError = errors
        var environment = ProcessInfo.processInfo.environment
        environment["LC_ALL"] = "C"; process.environment = environment
        process.terminationHandler = { _ in done.signal() }
        try process.run()
        if done.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if done.wait(timeout: .now() + 1) == .timedOut { kill(process.processIdentifier, SIGKILL); _ = done.wait(timeout: .now() + 2) }
            throw LabelFailure.message("The printer took too long to respond. Check USB, then refresh.")
        }
        let outputData = try Data(contentsOf: outputURL), errorData = try Data(contentsOf: errorURL)
        guard outputData.count <= 1048576, errorData.count <= 1048576 else { throw LabelFailure.message("Unexpectedly large printer response.") }
        let result = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)
        guard process.terminationStatus == 0 else { throw LabelFailure.message(error.isEmpty ? result : error) }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@MainActor final class LabelModel: ObservableObject {
    nonisolated static let queue = "XP330B_OpenSource"
    @Published var preset = "58 × 40 mm"
    @Published var width: Double = 58
    @Published var height: Double = 40
    @Published var title = "Product name"
    @Published var code = "12345678"
    @Published var footer = ""
    @Published var kind = "Code 128"
    @Published var copies = 1
    @Published var paper = "Labels with gaps"
    @Published var gap = 2
    @Published var darkness = 7
    @Published var rotate = false
    @Published var imported: URL?
    @Published var preview: PDFDocument?
    @Published var data: Data?
    @Published var error = ""
    @Published var status = "Checking USB printer…"
    @Published var ready = false
    @Published var working = false
    @Published var notice = ""
    @Published var devices: [String] = []
    @Published var selectedDevice = ""
    let sizes: [(Double, Double)] = [(30,20),(40,30),(50,30),(50,50),(58,40),(60,40),(70,50),(76,50),(58,100),(76,150)]
    var config: LabelConfig { LabelConfig(width: width, height: height, title: title, code: code, footer: footer, kind: kind, rotateImport: rotate) }
    var renderKey: String { "\(width)|\(height)|\(title)|\(code)|\(footer)|\(kind)|\(rotate)|\(imported?.path ?? "")" }
    var pageCount: Int { preview?.pageCount ?? 0 }
    var totalLabels: Int { pageCount * copies }

    init() {
        let defaults = UserDefaults.standard
        if let name = defaults.string(forKey: "preset") { preset = name }
        if let w = defaults.object(forKey: "width") as? Double { width = w }
        if let h = defaults.object(forKey: "height") as? Double { height = h }
        paper = defaults.string(forKey: "paper") ?? paper
        if defaults.object(forKey: "gap") != nil { gap = defaults.integer(forKey: "gap") }
        if defaults.object(forKey: "darkness") != nil { darkness = defaults.integer(forKey: "darkness") }
        if !(20...76).contains(width) || !(10...1000).contains(height) { width = 58; height = 40; preset = "58 × 40 mm" }
        gap = min(10, max(0, gap)); darkness = min(15, max(0, darkness))
    }
    func selectPreset() {
        if let item = sizes.first(where: { "\(Int($0.0)) × \(Int($0.1)) mm" == preset }) { width = item.0; height = item.1 }
        saveSettings()
    }
    func saveSettings() {
        let d = UserDefaults.standard
        d.set(preset, forKey: "preset"); d.set(width, forKey: "width"); d.set(height, forKey: "height")
        d.set(paper, forKey: "paper"); d.set(gap, forKey: "gap"); d.set(darkness, forKey: "darkness")
    }
    func refreshPreview() {
        saveSettings()
        do {
            let result = try LabelRenderer.pdf(config, imported: imported)
            data = result; preview = PDFDocument(data: result); error = ""
        } catch { data = nil; preview = nil; self.error = error.localizedDescription }
    }
    func refreshPrinter() {
        Task.detached {
            let message: String, isReady: Bool
            do {
                let devices = try Command.run("/usr/sbin/lpinfo", ["--include-schemes", "usb", "-v"], timeout: 10)
                let usb = devices.split(separator: "\n").compactMap { line -> String? in
                    let parts = line.split(separator: " ", maxSplits: 1)
                    guard parts.count == 2 else { return nil }
                    let value = String(parts[1])
                    return value.lowercased().hasPrefix("usb://xprinter/xp-330b?") ? value : nil
                }.sorted()
                await MainActor.run {
                    self.devices = usb
                    if !usb.contains(self.selectedDevice) { self.selectedDevice = usb.first ?? "" }
                }
                let queue = (try? Command.run("/usr/bin/lpstat", ["-p", LabelModel.queue])) ?? ""
                if usb.isEmpty { message = "Connect your XP-330B by USB"; isReady = false }
                else if queue.isEmpty { message = "USB found · click Set up printer"; isReady = false }
                else if queue.contains("disabled") { message = "Print queue paused · run Repair"; isReady = false }
                else {
                    let uri = try Command.run("/usr/bin/lpstat", ["-v", LabelModel.queue])
                    let configured = uri.components(separatedBy: ": ").last ?? ""
                    if !usb.contains(configured) { message = "USB port changed · click Set up printer"; isReady = false }
                    else { message = "USB connected · queue ready"; isReady = true; await MainActor.run { self.selectedDevice = configured } }
                }
            } catch { message = "Driver setup needed · run Repair"; isReady = false }
            await MainActor.run { self.status = message; self.ready = isReady }
        }
    }
    func importFile(_ url: URL) {
        imported = url; rotate = false; notice = ""; refreshPreview()
    }
    func chooseFile() {
        let panel = NSOpenPanel(); panel.title = "Open labels, an image, or a label CSV"
        panel.allowedContentTypes = [.pdf, .png, .jpeg, .tiff, .heic, .commaSeparatedText]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { importFile(url) }
    }
    func export() {
        guard let data = data else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "Labels-\(Int(width))x\(Int(height)).pdf"
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url, options: .atomic); notice = "PDF saved at the selected label size." }
            catch { self.error = error.localizedDescription }
        }
    }
    func printLabels() {
        guard ready, !working, let data = data else { return }
        guard paper == "Continuous / receipt" || gap > 0 else { error = "Gap or black mark height must be at least 1 mm."; return }
        if totalLabels > 20 {
            let alert = NSAlert(); alert.messageText = "Print \(totalLabels) labels?"
            alert.informativeText = "Check that the loaded stock is \(width.formatted()) × \(height.formatted()) mm."
            alert.addButton(withTitle: "Print"); alert.addButton(withTitle: "Cancel")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        working = true; notice = ""; error = ""
        let media: String
        if sizes.contains(where: { $0.0 == width && $0.1 == height }) {
            media = width > height ? "\(Int(height))x\(Int(width))mmRotated.Fullbleed" : "\(Int(width))x\(Int(height))mm.Fullbleed"
        } else { media = "Custom.\(width)x\(height)mm" }
        let type = paper == "Continuous / receipt" ? "Continue" : paper == "Black mark labels" ? "LabelMark" : "LabelGaps"
        let args = ["-d", Self.queue, "-n", String(copies), "-t", "Xprinter Labels", "-o", "PageSize=\(media)", "-o", "Resolution=203dpi",
                    "-o", "MediaMethod=Direct", "-o", "PaperType=\(type)", "-o", "GapsHeight=\(paper == "Continuous / receipt" ? 0 : gap)",
                    "-o", "Darkness=\(darkness)", "-o", "PrintSpeed=3",
                    "-o", "fit-to-page=false", "-o", "scaling=100", "-o", "number-up=1", "-o", "sides=one-sided"]
        Task.detached {
            do {
                let directory = try Command.temporaryDirectory()
                defer { try? FileManager.default.removeItem(at: directory) }
                let file = directory.appendingPathComponent("labels.pdf")
                try data.write(to: file)
                let result = try Command.run("/usr/bin/lp", args + [file.path])
                await MainActor.run { self.notice = "Sent to Xprinter. \(result)"; self.working = false }
            } catch { await MainActor.run { self.error = error.localizedDescription; self.working = false } }
        }
    }
    func repair(applyDefaults: Bool = false) {
        guard !working else { return }
        do { try config.validate() } catch { self.error = error.localizedDescription; return }
        guard paper == "Continuous / receipt" || gap > 0 else { error = "Gap or black mark height must be at least 1 mm."; return }
        let helper = "/Library/Printers/OpenXprinter/setup-printer.sh"
        guard FileManager.default.isExecutableFile(atPath: helper) else { error = "Install the Open Xprinter .pkg first, then open this app."; return }
        var arguments = [helper, "--configure"]
        if !selectedDevice.isEmpty { arguments += ["--device-uri", selectedDevice] }
        if applyDefaults {
            let size = sizes.contains(where: { $0.0 == width && $0.1 == height }) ?
                (width > height ? "\(Int(height))x\(Int(width))mmRotated.Fullbleed" : "\(Int(width))x\(Int(height))mm.Fullbleed") : "Custom.\(width)x\(height)mm"
            let type = paper == "Continuous / receipt" ? "Continue" : paper == "Black mark labels" ? "LabelMark" : "LabelGaps"
            arguments += ["--paper-size", size, "--stock", type, "--gap", String(gap), "--darkness", String(darkness)]
        }
        func shellQuote(_ value: String) -> String { "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let command = arguments.map(shellQuote).joined(separator: " ")
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges with prompt \"Set up the Open Xprinter USB label printer.\""
        working = true
        Task.detached {
            do {
                _ = try Command.run("/usr/bin/osascript", ["-e", appleScript], timeout: 180)
                await MainActor.run { self.working = false; self.notice = applyDefaults ? "Label size and stock saved for other Mac apps too." : "USB printer configured. Choose the label size loaded in your printer."; self.refreshPrinter() }
            } catch { await MainActor.run { self.working = false; self.error = error.localizedDescription } }
        }
    }
    func calibrate() {
        guard ready, !working, paper != "Continuous / receipt" else { return }
        do { try config.validate() } catch { self.error = error.localizedDescription; return }
        let alert = NSAlert()
        guard gap > 0 else { error = "Set a positive gap or mark height first."; return }
        alert.messageText = "Align the \(width.formatted()) × \(height.formatted()) mm roll?"
        alert.informativeText = "Load the roll and close the cover. The printer will feed to the start of the next label. This also happens automatically before each print job."
        alert.addButton(withTitle: "Align"); alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let mode = paper == "Black mark labels" ? "BLINE \(gap) mm,0 mm" : "GAP \(gap) mm,0 mm"
        let raw = "SIZE \(width) mm,\(height) mm\r\n\(mode)\r\nREFERENCE 0,0\r\nOFFSET 0 mm\r\nSET PEEL OFF\r\nSET CUTTER OFF\r\nHOME\r\n"
        working = true; error = ""; notice = ""
        Task.detached {
            do {
                let directory = try Command.temporaryDirectory()
                defer { try? FileManager.default.removeItem(at: directory) }
                let file = directory.appendingPathComponent("align.tspl")
                let queued = try Command.run("/usr/bin/lpstat", ["-W", "not-completed", "-o", Self.queue])
                guard queued.isEmpty else { throw LabelFailure.message("Wait for the current print jobs to finish, then calibrate.") }
                try Data(raw.utf8).write(to: file)
                let result = try Command.run("/usr/bin/lp", ["-d", Self.queue, "-t", "Label sensor calibration", "-o", "raw", "-o", "job-sheets=none,none", file.path])
                await MainActor.run { self.working = false; self.notice = "Alignment sent. Wait for the roll to stop, then print one label. \(result)" }
            } catch { await MainActor.run { self.working = false; self.error = error.localizedDescription } }
        }
    }
}

struct PDFPreview: NSViewRepresentable {
    var document: PDFDocument?
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.backgroundColor = .windowBackgroundColor
        return view
    }
    func updateNSView(_ view: PDFView, context: Context) {
        if view.document !== document { view.document = document; view.autoScales = true }
    }
}

struct LabelsView: View {
    @ObservedObject var model: LabelModel
    @State private var dropTarget = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "barcode.viewfinder").font(.system(size: 28)).foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Open Xprinter").font(.title2.weight(.semibold))
                    Text("XP-330B · USB · 203 dpi").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(model.ready ? .green : .orange).frame(width: 8, height: 8)
                Text(model.status).font(.callout)
                Button { model.refreshPrinter() } label: { Image(systemName: "arrow.clockwise") }.help("Refresh printer status")
            }.padding(20)
            Divider()
            if !model.ready {
                HStack {
                    Text("Connect USB, load your labels, then set up the printer.")
                    Spacer()
                    Button("Set up printer") { model.repair(applyDefaults: true) }.buttonStyle(.borderedProminent).disabled(model.working || model.devices.isEmpty)
                }.padding(14).background(.blue.opacity(0.06))
            }
            HStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Match your loaded label").font(.headline)
                        if model.devices.count > 1 {
                            Picker("USB printer", selection: $model.selectedDevice) {
                                ForEach(model.devices, id: \.self) { Text($0).tag($0) }
                            }
                            Button("Use selected printer") { model.repair() }.disabled(model.working)
                        }
                        Picker("Label size", selection: $model.preset) {
                            ForEach(model.sizes.indices, id: \.self) { index in
                                let item = model.sizes[index]
                                Text("\(Int(item.0)) × \(Int(item.1)) mm").tag("\(Int(item.0)) × \(Int(item.1)) mm")
                            }
                            Text("Custom size").tag("Custom size")
                        }
                        if model.preset == "Custom size" {
                            HStack {
                                TextField("Width (mm)", value: $model.width, format: .number)
                                Text("×")
                                TextField("Height (mm)", value: $model.height, format: .number)
                            }
                            Text("Width 20–76 mm · height 10–1,000 mm").font(.caption).foregroundStyle(.secondary)
                        }
                        Picker("Stock", selection: $model.paper) {
                            Text("Labels with gaps").tag("Labels with gaps")
                            Text("Black mark labels").tag("Black mark labels")
                            Text("Continuous / receipt").tag("Continuous / receipt")
                        }
                        if model.paper != "Continuous / receipt" { Stepper("Gap / mark: \(model.gap) mm", value: $model.gap, in: 0...10) }
                        if model.paper != "Continuous / receipt" {
                            Button("Align label start…") { model.calibrate() }
                                .disabled(!model.ready || model.working)
                                .help("Feed to the start of the next label. The driver also aligns automatically before each job.")
                        }
                        Button("Save as default for other apps…") { model.repair(applyDefaults: true) }.disabled(model.working || model.devices.isEmpty)
                        Divider()
                        Text("2. Create or open labels").font(.headline)
                        if let imported = model.imported {
                            Label(imported.lastPathComponent, systemImage: "doc").lineLimit(2)
                            Text("\(model.pageCount) label page\(model.pageCount == 1 ? "" : "s"). Matching PDF sizes are preserved; larger pages are fitted.").font(.caption).foregroundStyle(.secondary)
                            Toggle("Rotate source 90°", isOn: $model.rotate)
                            Button("Create a new label") { model.imported = nil; model.refreshPreview() }
                        } else {
                            Picker("Label type", selection: $model.kind) {
                                Text("Barcode · Code 128").tag("Code 128")
                                Text("QR code").tag("QR code")
                                Text("Text only").tag("Text only")
                            }
                            TextField("Product name / title (optional)", text: $model.title)
                            TextField(model.kind == "QR code" ? "QR content or URL" : "Barcode value / label text", text: $model.code)
                            TextField("Price / footer (optional)", text: $model.footer)
                        }
                        Button("Open PDF, image or CSV…") { model.chooseFile() }
                        Text("Drop a file onto the preview. CSV columns: code; optional title, footer, type, quantity.").font(.caption).foregroundStyle(.secondary)
                        Divider()
                        Text("3. Print").font(.headline)
                        Stepper("Copies: \(model.copies)", value: $model.copies, in: 1...100)
                        HStack {
                            Button("Save PDF…") { model.export() }.disabled(model.data == nil)
                            Spacer()
                            Button(model.working ? "Working…" : "Print \(model.totalLabels) label\(model.totalLabels == 1 ? "" : "s")") { model.printLabels() }
                                .buttonStyle(.borderedProminent).keyboardShortcut("p", modifiers: .command)
                                .disabled(!model.ready || model.data == nil || model.working)
                        }
                        DisclosureGroup("Printer settings & help") {
                            VStack(alignment: .leading, spacing: 10) {
                                Stepper("Darkness: \(model.darkness)", value: $model.darkness, in: 0...15)
                                Button("Install / repair USB driver") { model.repair() }.disabled(model.working)
                                Button("Open Print Center") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Utilities/Print Center.app")) }
                                Text("Choose “Xprinter XP-330B Labels (Open Source)” in any Mac app. Match the page size to the loaded roll. For labels skipping or crossing gaps, check roll size and gap/mark height, then align the label start.").font(.caption).foregroundStyle(.secondary)
                                Link("Setup, troubleshooting & source code", destination: URL(string: "https://github.com/ismoil-nosr/xprinter-macos")!).font(.caption)
                                Text("The print head is 76 mm wide. A standard 4 × 6 inch shipping label needs a wider printer; shrinking it may make its barcode unreadable.").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 10)
                        }
                    }.textFieldStyle(.roundedBorder).padding(20)
                }.frame(width: 350)
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Label preview").font(.headline)
                        Spacer()
                        Text("\(model.width.formatted()) × \(model.height.formatted()) mm · \(model.pageCount) page\(model.pageCount == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                    }.padding(.horizontal, 20).padding(.top, 18)
                    if let doc = model.preview {
                        PDFPreview(document: doc).overlay { if dropTarget { RoundedRectangle(cornerRadius: 8).stroke(.blue, lineWidth: 3) } }
                    } else {
                        VStack(spacing: 10) { Image(systemName: "rectangle.dashed").font(.largeTitle); Text("Adjust the fields to create a label.") }.frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(.secondary)
                    }
                    Text("Black and white · 203 dpi · prints at the selected physical label size").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20).padding(.bottom, 16)
                }.frame(maxWidth: .infinity)
                    .onDrop(of: [UTType.fileURL.identifier], isTargeted: $dropTarget) { providers in
                        guard let provider = providers.first else { return false }
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                            let url: URL?
                            if let bytes = item as? Data { url = URL(dataRepresentation: bytes, relativeTo: nil) }
                            else if let value = item as? URL { url = value }
                            else { url = nil }
                            if let url = url { Task { @MainActor in model.importFile(url) } }
                        }
                        return true
                    }
            }
            if !model.error.isEmpty { Text(model.error).foregroundStyle(.red).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.red.opacity(0.06)) }
            if !model.notice.isEmpty { Text(model.notice).font(.callout).frame(maxWidth: .infinity, alignment: .leading).padding(14).background(.blue.opacity(0.06)) }
        }
        .onAppear { model.refreshPreview(); model.refreshPrinter() }
        .onChange(of: model.preset) { _, _ in model.selectPreset() }
        .onChange(of: model.renderKey) { _, _ in model.refreshPreview() }
        .onChange(of: model.paper) { _, _ in model.saveSettings() }
        .onChange(of: model.gap) { _, _ in model.saveSettings() }
        .onChange(of: model.darkness) { _, _ in model.saveSettings() }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = LabelModel()
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1020, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Open Xprinter"; window.minSize = NSSize(width: 900, height: 650)
        window.contentView = NSHostingView(rootView: LabelsView(model: model))
        window.center(); window.makeKeyAndOrderFront(nil); self.window = window
        let menu = NSMenu()
        let appItem = NSMenuItem(); menu.addItem(appItem)
        let appMenu = NSMenu(); appItem.submenu = appMenu
        appMenu.addItem(withTitle: "About Open Xprinter", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Open Xprinter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let fileItem = NSMenuItem(); menu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File"); fileItem.submenu = fileMenu
        for (title, action, key) in [("Open…", #selector(openFile), "o"), ("Save PDF…", #selector(saveFile), "s"), ("Print Labels", #selector(printFile), "p")] {
            let item = fileMenu.addItem(withTitle: title, action: action, keyEquivalent: key); item.target = self
        }
        let editItem = NSMenuItem(); menu.addItem(editItem); let editMenu = NSMenu(title: "Edit"); editItem.submenu = editMenu
        for (title, action, key) in [("Undo", Selector(("undo:")), "z"), ("Cut", #selector(NSText.cut(_:)), "x"), ("Copy", #selector(NSText.copy(_:)), "c"), ("Paste", #selector(NSText.paste(_:)), "v"), ("Select All", #selector(NSText.selectAll(_:)), "a")] { editMenu.addItem(withTitle: title, action: action, keyEquivalent: key) }
        NSApplication.shared.mainMenu = menu
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    @objc func openFile() { model.chooseFile() }
    @objc func saveFile() { model.export() }
    @objc func printFile() { model.printLabels() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        if let file = filenames.first { model.importFile(URL(fileURLWithPath: file)) }
        sender.reply(toOpenOrPrint: .success)
    }
}

@main struct Main {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") {
            do {
                let output = CommandLine.arguments.last!
                try LabelRenderer.selfTest(at: URL(fileURLWithPath: output, isDirectory: true))
            } catch { fputs("Self-test failed: \(error.localizedDescription)\n", stderr); exit(1) }
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate; app.setActivationPolicy(.regular); app.run()
        withExtendedLifetime(delegate) {}
    }
}

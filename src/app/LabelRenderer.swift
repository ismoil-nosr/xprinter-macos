// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ismoil Nosr
import AppKit
import CoreImage
import PDFKit
import Vision

enum LabelFailure: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self { case .message(let text): return text }
    }
}

struct LabelConfig {
    var width: Double = 58
    var height: Double = 40
    var title: String = "Product name"
    var code: String = "12345678"
    var footer: String = ""
    var kind: String = "Code 128"
    var rotateImport = false
    var pageSize: CGSize { CGSize(width: width * 72 / 25.4, height: height * 72 / 25.4) }
    func validate() throws {
        guard width.isFinite, height.isFinite, (20...76).contains(width), (10...1000).contains(height) else {
            throw LabelFailure.message("Choose a width from 20 to 76 mm and height from 10 to 1,000 mm.")
        }
        guard title.count <= 120, footer.count <= 160 else {
            throw LabelFailure.message("Keep the title under 120 characters and the footer under 160.")
        }
    }
}

enum LabelRenderer {
    static let dpi = 203.0
    static let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    static func drawText(_ text: String, in rect: CGRect, fontSize: CGFloat, bold: Bool = false, maxLines: Int = 1) throws {
        guard !text.isEmpty else { return }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = maxLines == 1 ? .byTruncatingTail : .byWordWrapping
        var size = fontSize
        var value = NSAttributedString()
        while size >= 11 {
            value = NSAttributedString(string: text, attributes: [
                .font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
                .foregroundColor: NSColor.black, .paragraphStyle: paragraph
            ])
            if value.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height <= rect.height { break }
            size -= 1
        }
        if maxLines > 1 && value.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin]).height > rect.height + 1 {
            throw LabelFailure.message("The title or text is too long for this label. Shorten it or choose a larger label.")
        }
        let actualHeight = min(rect.height, value.boundingRect(with: rect.size, options: [.usesLineFragmentOrigin]).height)
        value.draw(with: CGRect(x: rect.minX, y: rect.midY - actualHeight / 2, width: rect.width, height: actualHeight + 1), options: [.usesLineFragmentOrigin])
    }

    static func barcode(_ value: String, qr: Bool) throws -> CGImage {
        guard !value.isEmpty else { throw LabelFailure.message("Enter a barcode value or QR content.") }
        let filter: CIFilter
        if qr {
            guard value.utf8.count <= 800 else { throw LabelFailure.message("Keep the QR content under 800 bytes.") }
            filter = CIFilter(name: "CIQRCodeGenerator")!
            filter.setValue(Data(value.utf8), forKey: "inputMessage")
            filter.setValue("M", forKey: "inputCorrectionLevel")
        } else {
            guard value.unicodeScalars.allSatisfy({ (32...126).contains($0.value) }), value.count <= 80 else {
                throw LabelFailure.message("Code 128 accepts up to 80 printable English letters, digits and symbols. Use QR for Cyrillic or other Unicode text.")
            }
            filter = CIFilter(name: "CICode128BarcodeGenerator")!
            filter.setValue(value.data(using: .ascii)!, forKey: "inputMessage")
            filter.setValue(10, forKey: "inputQuietSpace")
        }
        guard let image = filter.outputImage, let cg = ciContext.createCGImage(image, from: image.extent) else {
            throw LabelFailure.message("Could not create this barcode.")
        }
        return cg
    }

    static func labelImage(_ config: LabelConfig) throws -> CGImage {
        try config.validate()
        let w = Int((config.width * dpi / 25.4).rounded())
        let h = Int((config.height * dpi / 25.4).rounded())
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw LabelFailure.message("Could not create the label preview.")
        }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.interpolationQuality = .none
        let margin = CGFloat((2 * dpi / 25.4).rounded())
        let contentWidth = CGFloat(w) - 2 * margin
        let titleHeight: CGFloat = config.title.isEmpty ? 0 : max(20, min(42, CGFloat(h) * 0.16))
        let footerHeight: CGFloat = config.footer.isEmpty ? 0 : max(18, min(28, CGFloat(h) * 0.12))
        let captionHeight: CGFloat = config.kind == "Text only" ? 0 : 20
        let space: CGFloat = 6
        let top = CGFloat(h) - margin
        let codeBottom = margin + footerHeight + (footerHeight > 0 ? space : 0) + captionHeight + space
        let codeTop = top - titleHeight - (titleHeight > 0 ? space : 0)
        let area = CGRect(x: margin, y: codeBottom, width: contentWidth, height: codeTop - codeBottom)
        guard area.height >= 24 else { throw LabelFailure.message("This label is too short for all these fields. Remove the title/footer or choose a taller label.") }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        try drawText(config.title, in: CGRect(x: margin, y: top - titleHeight, width: contentWidth, height: titleHeight), fontSize: min(28, titleHeight * 0.78), bold: true, maxLines: 2)
        try drawText(config.footer, in: CGRect(x: margin, y: margin, width: contentWidth, height: footerHeight), fontSize: min(20, footerHeight * 0.85), maxLines: 1)
        if config.kind == "Text only" {
            try drawText(config.code, in: area, fontSize: min(42, area.height * 0.5), bold: true, maxLines: 3)
        } else {
            let isQR = config.kind == "QR code"
            let image = try barcode(config.code, qr: isQR)
            let quiet = isQR ? 4 : 0
            let modules = image.width + quiet * 2
            let scale = Int(floor((isQR ? min(area.width, area.height) : area.width) / CGFloat(modules)))
            guard scale >= 2 else {
                throw LabelFailure.message("This code is too dense for the selected label at 203 dpi. Shorten the value or choose a wider/taller label.")
            }
            let imageWidth = CGFloat(image.width * scale)
            let imageHeight = isQR ? CGFloat(image.height * scale) : min(110, area.height)
            let x = floor(area.midX - imageWidth / 2)
            let y = floor(area.midY - imageHeight / 2)
            ctx.draw(image, in: CGRect(x: x, y: y, width: imageWidth, height: imageHeight))
            try drawText(config.code, in: CGRect(x: margin, y: codeBottom - captionHeight - space, width: contentWidth, height: captionHeight), fontSize: 15)
        }
        guard let result = ctx.makeImage() else { throw LabelFailure.message("Could not render the label.") }
        return result
    }

    static func parseCSV(_ text: String, config: LabelConfig) throws -> [LabelConfig] {
        var rows: [[String]] = []
        var row: [String] = [], field = "", quoted = false
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if ch == "\"" {
                if quoted && i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                else { quoted.toggle() }
            } else if ch == "," && !quoted { row.append(field); field = "" }
            else if (ch == "\n" || ch == "\r") && !quoted {
                row.append(field); field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
                if ch == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" { i += 1 }
            } else { field.append(ch) }
            i += 1
        }
        guard !quoted else { throw LabelFailure.message("CSV has an unclosed quoted field.") }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        guard let first = rows.first, rows.count > 1 else { throw LabelFailure.message("CSV needs a header row and at least one label.") }
        let headers = first.map { $0.replacingOccurrences(of: "\u{FEFF}", with: "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard Set(headers).count == headers.count, headers.contains("code") else {
            throw LabelFailure.message("CSV needs a code column and unique headers. Optional: title, footer, type, quantity.")
        }
        var result: [LabelConfig] = []
        for (index, cells) in rows.dropFirst().enumerated() {
            guard cells.count == headers.count else { throw LabelFailure.message("CSV row \(index + 2) has the wrong number of columns.") }
            let record = Dictionary(uniqueKeysWithValues: zip(headers, cells))
            var item = config
            item.title = record["title"] ?? ""
            item.code = record["code"] ?? ""
            item.footer = record["footer"] ?? ""
            switch (record["type"] ?? "code128").lowercased() {
            case "code128", "code 128", "barcode": item.kind = "Code 128"
            case "qr", "qrcode", "qr code": item.kind = "QR code"
            case "text", "text only": item.kind = "Text only"
            default: throw LabelFailure.message("CSV row \(index + 2): type must be code128, qr or text.")
            }
            guard let quantity = Int(record["quantity"] ?? "1"), (1...100).contains(quantity), result.count + quantity <= 500 else {
                throw LabelFailure.message("CSV quantities must be 1–100 per row and at most 500 labels in total.")
            }
            result.append(contentsOf: Array(repeating: item, count: quantity))
        }
        return result
    }

    static func pdf(_ config: LabelConfig, imported: URL? = nil) throws -> Data {
        try config.validate()
        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: config.pageSize)
        guard let consumer = CGDataConsumer(data: data as CFMutableData), let ctx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw LabelFailure.message("Could not create a PDF.")
        }
        func startPage() { ctx.beginPDFPage(nil); ctx.setFillColor(CGColor(gray: 1, alpha: 1)); ctx.fill(mediaBox) }
        if let url = imported {
            let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard fileSize <= 32 * 1024 * 1024 else { throw LabelFailure.message("Choose a file smaller than 32 MB.") }
            switch url.pathExtension.lowercased() {
            case "csv":
                let text = try String(contentsOf: url, encoding: .utf8)
                for record in try parseCSV(text, config: config) {
                    let image = try labelImage(record)
                    startPage(); ctx.interpolationQuality = .none; ctx.draw(image, in: mediaBox); ctx.endPDFPage()
                }
            case "pdf":
                guard let doc = CGPDFDocument(url as CFURL), (1...200).contains(doc.numberOfPages) else { throw LabelFailure.message("Choose a readable PDF with 1–200 pages.") }
                for n in 1...doc.numberOfPages {
                    guard let page = doc.page(at: n) else { throw LabelFailure.message("Could not read PDF page \(n).") }
                    var sourceSize = page.getBoxRect(.cropBox).size
                    let rotation = (Int(page.rotationAngle) + (config.rotateImport ? 90 : 0)) % 180
                    if rotation != 0 { sourceSize = CGSize(width: sourceSize.height, height: sourceSize.width) }
                    let sameSize = abs(sourceSize.width - mediaBox.width) < 0.5 && abs(sourceSize.height - mediaBox.height) < 0.5
                    let target = sameSize ? mediaBox : mediaBox.insetBy(dx: 2 * 72 / 25.4, dy: 2 * 72 / 25.4)
                    startPage(); ctx.saveGState()
                    ctx.concatenate(page.getDrawingTransform(.cropBox, rect: target, rotate: config.rotateImport ? 90 : 0, preserveAspectRatio: true))
                    ctx.drawPDFPage(page); ctx.restoreGState(); ctx.endPDFPage()
                }
            default:
                guard let image = NSImage(contentsOf: url), let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { throw LabelFailure.message("Choose a PDF, image or UTF-8 CSV file.") }
                guard cg.width <= 10000, cg.height <= 10000, cg.width * cg.height <= 20000000 else { throw LabelFailure.message("Choose an image with at most 20 million pixels.") }
                startPage()
                let target = mediaBox.insetBy(dx: 2 * 72 / 25.4, dy: 2 * 72 / 25.4)
                let rotatedSize = config.rotateImport ? CGSize(width: cg.height, height: cg.width) : CGSize(width: cg.width, height: cg.height)
                let scale = min(target.width / rotatedSize.width, target.height / rotatedSize.height)
                ctx.saveGState(); ctx.translateBy(x: target.midX, y: target.midY)
                if config.rotateImport { ctx.rotate(by: .pi / 2) }
                ctx.interpolationQuality = .high
                ctx.draw(cg, in: CGRect(x: -CGFloat(cg.width) * scale / 2, y: -CGFloat(cg.height) * scale / 2, width: CGFloat(cg.width) * scale, height: CGFloat(cg.height) * scale))
                ctx.restoreGState(); ctx.endPDFPage()
            }
        } else {
            let image = try labelImage(config)
            startPage(); ctx.interpolationQuality = .none; ctx.draw(image, in: mediaBox); ctx.endPDFPage()
        }
        ctx.closePDF()
        return data as Data
    }

    static func selfTest(at root: URL) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var report: [[String: Any]] = []
        for dimensions in [(30.0, 20.0), (58.0, 40.0)] {
          for kind in ["Code 128", "QR code"] {
            var cfg = LabelConfig(); cfg.kind = kind; cfg.width = dimensions.0; cfg.height = dimensions.1
            let image = try labelImage(cfg)
            let req = VNDetectBarcodesRequest()
            try VNImageRequestHandler(cgImage: image).perform([req])
            guard req.results?.contains(where: { $0.payloadStringValue == cfg.code }) == true else { throw LabelFailure.message("\(kind) failed decoding at printer resolution.") }
            let prefix = kind == "Code 128" ? "barcode" : "qr"
            let name = "\(prefix)-\(Int(cfg.width))x\(Int(cfg.height)).pdf"
            let pdfData = try pdf(cfg)
            try pdfData.write(to: root.appendingPathComponent(name))
            let doc = PDFDocument(data: pdfData)!
            let bounds = doc.page(at: 0)!.bounds(for: .mediaBox)
            guard abs(bounds.width - cfg.pageSize.width) < 0.01 && abs(bounds.height - cfg.pageSize.height) < 0.01 else { throw LabelFailure.message("PDF size mismatch.") }
            report.append(["test": name, "decoded": true, "pixels": [image.width, image.height], "size_mm": [cfg.width, cfg.height]])
          }
        }
        var unicode = LabelConfig(); unicode.width = 50; unicode.height = 30
        unicode.title = "Товар · Mahsulot"; unicode.kind = "QR code"; unicode.code = "Тест-123"; unicode.footer = "25 000 UZS"
        try pdf(unicode).write(to: root.appendingPathComponent("unicode-50x30.pdf"))
        let req = VNDetectBarcodesRequest(); try VNImageRequestHandler(cgImage: labelImage(unicode)).perform([req])
        guard req.results?.contains(where: { $0.payloadStringValue == unicode.code }) == true else { throw LabelFailure.message("Unicode QR decoding failed.") }
        report.append(["test": "unicode-50x30.pdf", "decoded": true])
        var tooDense = LabelConfig(); tooDense.code = String(repeating: "W", count: 60)
        do { _ = try labelImage(tooDense); throw LabelFailure.message("Dense barcode was not rejected.") }
        catch let error as LabelFailure { guard error.localizedDescription.contains("too dense") else { throw error } }
        let records = try parseCSV("title,code,footer,type,quantity\r\n\"Item, one\",12345678,,code128,2\r\n\"Item \"\"two\"\"\",SKU002,,qr,1\r\n", config: LabelConfig())
        guard records.count == 3, records[0].title == "Item, one", records[2].title == "Item \"two\"" else { throw LabelFailure.message("CSV parsing failed.") }
        let csv = root.appendingPathComponent("sample-labels.csv")
        try "title,code,footer,type,quantity\nProduct one,12345678,,code128,2\nProduct two,SKU002,,qr,1\n".write(to: csv, atomically: true, encoding: .utf8)
        let batch = try pdf(LabelConfig(), imported: csv)
        guard PDFDocument(data: batch)?.pageCount == 3 else { throw LabelFailure.message("CSV page count failed.") }
        try batch.write(to: root.appendingPathComponent("batch-58x40.pdf"))
        let fitted = try pdf(LabelConfig(), imported: root.appendingPathComponent("barcode-30x20.pdf"))
        guard PDFDocument(data: fitted)?.pageCount == 1 else { throw LabelFailure.message("PDF import failed.") }
        try fitted.write(to: root.appendingPathComponent("imported-fitted-58x40.pdf"))
        var stock = LabelConfig(); stock.width = 58; stock.height = 40
        let stockImport = try pdf(stock, imported: root.appendingPathComponent("barcode-58x40.pdf"))
        try stockImport.write(to: root.appendingPathComponent("imported-58x40.pdf"))
        report.append(["test": "dense-code-rejected", "passed": true])
        report.append(["test": "CSV quoting and 3-page batch", "passed": true])
        report.append(["test": "PDF import", "passed": true])
        let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: root.appendingPathComponent("self-test.json"))
        print(String(data: json, encoding: .utf8)!)
    }
}

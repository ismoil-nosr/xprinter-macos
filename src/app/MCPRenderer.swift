// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ismoil Nosr
import AppKit
import PDFKit

/// A bounded stdin/stdout bridge. Rendering shares the GUI's label implementation;
/// this entry point never configures a queue or submits a print job.
enum MCPRenderer {
    struct Entry: Decodable {
        let kind: String
        let title: String?
        let code: String
        let footer: String?
        let quantity: Int?
    }
    struct Request: Decodable {
        let widthMm: Double
        let heightMm: Double
        let labels: [Entry]?
        let pdfBase64: String?
        let rotate: Bool?
    }
    struct Response: Encodable {
        let pdfBase64: String
        let previewBase64: String
        let pages: Int
        let widthMm: Double
        let heightMm: Double
    }
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ text: String) { errorDescription = text }
    }

    static func render(_ request: Request) throws -> Response {
        guard request.widthMm.isFinite, request.heightMm.isFinite,
              (20...76).contains(request.widthMm), (10...200).contains(request.heightMm) else {
            throw Failure("MCP label dimensions must be 20–76 mm across and 10–200 mm along the feed.")
        }
        guard (request.labels != nil) != (request.pdfBase64 != nil) else {
            throw Failure("Supply labels or a PDF, exclusively.")
        }
        var config = LabelConfig()
        config.width = request.widthMm; config.height = request.heightMm
        config.rotateImport = request.rotate ?? false
        let document: PDFDocument
        if let entries = request.labels {
            guard (1...50).contains(entries.count) else { throw Failure("Supply 1–50 label records.") }
            document = PDFDocument()
            for entry in entries {
                let quantity = entry.quantity ?? 1
                guard (1...100).contains(quantity), document.pageCount + quantity <= 100 else {
                    throw Failure("The batch must contain at most 100 labels.")
                }
                config.title = entry.title ?? ""; config.code = entry.code; config.footer = entry.footer ?? ""
                switch entry.kind {
                case "code128": config.kind = "Code 128"
                case "qr": config.kind = "QR code"
                case "text": config.kind = "Text only"
                default: throw Failure("Label kind must be code128, qr or text.")
                }
                guard let item = PDFDocument(data: try LabelRenderer.pdf(config)), let page = item.page(at: 0) else {
                    throw Failure("Could not render the label.")
                }
                for _ in 0..<quantity {
                    guard let copy = page.copy() as? PDFPage else { throw Failure("Could not copy the label page.") }
                    document.insert(copy, at: document.pageCount)
                }
            }
        } else {
            guard let source = Data(base64Encoded: request.pdfBase64!), source.count <= 2 * 1024 * 1024,
                  let input = PDFDocument(data: source), !input.isLocked, (1...100).contains(input.pageCount) else {
                throw Failure("Supply an unencrypted PDF smaller than 2 MiB with 1–100 pages.")
            }
            let folder = FileManager.default.temporaryDirectory.appendingPathComponent("open-xprinter-mcp-" + UUID().uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false,
                                                    attributes: [.posixPermissions: 0o700])
            defer { try? FileManager.default.removeItem(at: folder) }
            let file = folder.appendingPathComponent("source.pdf")
            try source.write(to: file, options: .withoutOverwriting)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
            guard let result = PDFDocument(data: try LabelRenderer.pdf(config, imported: file)) else {
                throw Failure("Could not fit the PDF to the loaded label size.")
            }
            document = result
        }
        let pixelWidth = Int((config.width * LabelRenderer.dpi / 25.4).rounded())
        let pixelHeight = Int((config.height * LabelRenderer.dpi / 25.4).rounded())
        guard pixelWidth * pixelHeight * document.pageCount <= 40_000_000,
              let pdf = document.dataRepresentation(), pdf.count <= 6 * 1024 * 1024,
              let page = document.page(at: 0),
              let context = CGContext(data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8,
                                      bytesPerRow: pixelWidth * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
            throw Failure("The rendered batch is too large. Split it into smaller batches.")
        }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))
        context.scaleBy(x: CGFloat(pixelWidth) / config.pageSize.width, y: CGFloat(pixelHeight) / config.pageSize.height)
        context.interpolationQuality = .none
        page.draw(with: .mediaBox, to: context)
        guard let image = context.makeImage(),
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw Failure("Could not create the preview.")
        }
        return Response(pdfBase64: pdf.base64EncodedString(), previewBase64: png.base64EncodedString(),
                        pages: document.pageCount, widthMm: config.width, heightMm: config.height)
    }

    static func run() -> Int32 {
        Localization.configure(.english)
        do {
            var input = Data()
            while let chunk = try FileHandle.standardInput.read(upToCount: 64 * 1024), !chunk.isEmpty {
                input.append(chunk)
                guard input.count <= 3 * 1024 * 1024 else { throw Failure("Renderer input exceeds 3 MiB.") }
            }
            let request = try JSONDecoder().decode(Request.self, from: input)
            let output = try JSONEncoder().encode(render(request))
            try FileHandle.standardOutput.write(contentsOf: output)
            return 0
        } catch {
            // JSON is the only stdout format, including errors. No label contents in diagnostics.
            let output = (try? JSONSerialization.data(withJSONObject: ["error": error.localizedDescription])) ?? Data()
            try? FileHandle.standardOutput.write(contentsOf: output)
            return 1
        }
    }
}

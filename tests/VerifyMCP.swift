// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import ImageIO
import Vision

enum CheckError: Error { case failed(String) }
func require(_ value: Bool, _ text: String) throws { if !value { throw CheckError.failed(text) } }
let executable = CommandLine.arguments[1]
let output = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
func call(_ request: [String: Any], success: Bool = true) throws -> [String: Any] {
    let process = Process(); let input = Pipe(); let result = Pipe(); let errors = Pipe()
    process.executableURL = URL(fileURLWithPath: executable); process.arguments = ["--mcp-render"]
    process.standardInput = input; process.standardOutput = result; process.standardError = errors
    try process.run()
    let data = try JSONSerialization.data(withJSONObject: request)
    // Several writes exercise the streaming stdin reader.
    for start in stride(from: 0, to: data.count, by: 37) { try input.fileHandleForWriting.write(contentsOf: data.subdata(in: start..<min(start + 37, data.count))) }
    try input.fileHandleForWriting.close()
    let response = result.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
    try require((process.terminationStatus == 0) == success, "Unexpected renderer exit status")
    return try JSONSerialization.jsonObject(with: response) as! [String: Any]
}
func verify(_ response: [String: Any], pages: Int, code: String?) throws {
    let pdf = Data(base64Encoded: response["pdfBase64"] as! String)!
    let png = Data(base64Encoded: response["previewBase64"] as! String)!
    let document = CGPDFDocument(CGDataProvider(data: pdf as CFData)!)!
    try require(document.numberOfPages == pages && response["pages"] as? Int == pages, "Page count changed")
    let bounds = document.page(at: 1)!.getBoxRect(.mediaBox)
    try require(abs(bounds.width - 58 * 72 / 25.4) < 0.01 && abs(bounds.height - 40 * 72 / 25.4) < 0.01, "Physical dimensions changed")
    let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithData(png as CFData, nil)!, 0, nil)!
    try require(image.width == 464 && image.height == 320, "Preview must use printer resolution")
    if let code = code {
        let request = VNDetectBarcodesRequest(); request.symbologies = [.qr, .code128]; request.usesCPUOnly = true
        try VNImageRequestHandler(cgImage: image).perform([request])
        try require(request.results?.contains(where: { $0.payloadStringValue == code }) == true, "MCP preview barcode did not decode")
    }
    try pdf.write(to: output.appendingPathComponent("mcp-label.pdf"))
    try png.write(to: output.appendingPathComponent("mcp-label.png"))
}
let code = "中文测试-123"
let generated = try call(["widthMm": 58, "heightMm": 40, "labels": [["kind": "qr", "code": code, "title": "商品 · Товар", "footer": "¥25", "quantity": 2]]])
try verify(generated, pages: 2, code: code)
let imported = try call(["widthMm": 58, "heightMm": 40, "pdfBase64": generated["pdfBase64"]!])
try verify(imported, pages: 2, code: code)
let barcode = try call(["widthMm": 58, "heightMm": 40, "labels": [["kind": "code128", "code": "12345678", "title": "Product", "quantity": 1]]])
try verify(barcode, pages: 1, code: "12345678")
for invalid: [String: Any] in [
    ["widthMm": 0, "heightMm": 40, "labels": []],
    ["widthMm": 58, "heightMm": 40, "labels": [["kind": "qr", "code": code, "quantity": 101]]],
    ["widthMm": 58, "heightMm": 40, "labels": [["kind": "unknown", "code": code]]],
    ["widthMm": 58, "heightMm": 40, "pdfBase64": "not-a-pdf"],
    ["widthMm": 58, "heightMm": 40, "labels": [], "pdfBase64": generated["pdfBase64"]!],
] {
    let result = try call(invalid, success: false)
    try require(result["error"] is String, "Invalid request must return a JSON error")
}
let report: [String: Any] = ["native_mcp_bridge": "passed", "physical_size_mm": [58, 40], "preview_pixels": [464, 320], "chinese_qr": "decoded", "code128": "decoded", "pdf_import": "decoded", "invalid_requests": 5]
let json = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("mcp-renderer.json"))
print(String(data: json, encoding: .utf8)!)

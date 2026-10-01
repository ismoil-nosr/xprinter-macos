// SPDX-License-Identifier: MIT
import Foundation
import CoreGraphics
import Vision

@main struct VerifyTSPL {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "tspl" && ($0.lastPathComponent.contains("LabelGaps") || $0.lastPathComponent.contains("Continue") || $0.lastPathComponent.contains("LabelMark")) }
        var results: [[String: Any]] = []
        for file in files.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let data = try Data(contentsOf: file)
            var cursor = data.startIndex
            var decoded: [String] = []
            while cursor < data.endIndex, let range = data.range(of: Data("BITMAP ".utf8), in: cursor..<data.endIndex) {
                var start = range.upperBound
                var commas = 0
                while start < data.endIndex && commas < 5 {
                    if data[start] == 44 { commas += 1 }
                    start += 1
                }
                guard commas == 5 else { fatalError("Incomplete BITMAP header") }
                let parts = String(decoding: data[range.upperBound..<start], as: UTF8.self).split(separator: ",")
                let stride = Int(parts[2])!, height = Int(parts[3])!, width = stride * 8
                guard data.endIndex - start >= stride * height, stride > 0, height > 0, Int(parts[4]) == 0 else { fatalError("Invalid BITMAP payload") }
                var pixels = Data(count: width * height)
                for y in 0..<height {
                    for x in 0..<width {
                        let bit = data[start + y * stride + x / 8] & (0x80 >> (x % 8))
                        pixels[y * width + x] = bit == 0 ? 0 : 255
                    }
                }
                let provider = CGDataProvider(data: pixels as CFData)!
                let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(), bitmapInfo: [], provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
                let request = VNDetectBarcodesRequest()
                request.symbologies = [.code128, .qr]
                request.usesCPUOnly = true
                try VNImageRequestHandler(cgImage: image).perform([request])
                let values = request.results?.compactMap(\.payloadStringValue) ?? []
                guard !values.isEmpty else { fatalError("Barcode failed to decode in final printer data: \(file.lastPathComponent)") }
                decoded += values
                cursor = start + stride * height
            }
            guard !decoded.isEmpty else { fatalError("No BITMAP found") }
            if file.lastPathComponent.hasPrefix("chinese-") && !decoded.contains("中文测试-123") { fatalError("Chinese QR payload changed in final printer data") }
            results.append(["file": file.lastPathComponent, "decoded": decoded])
            print("\(file.lastPathComponent): \(decoded) PASS")
        }
        guard files.count >= 8 else { fatalError("Missing driver validation cases") }
        let json = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        try json.write(to: root.appendingPathComponent("final-bitmap-decode.json"))
    }
}

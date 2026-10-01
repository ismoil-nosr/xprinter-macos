// SPDX-License-Identifier: MIT
import AppKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
NSColor(calibratedRed: 0.05, green: 0.34, blue: 0.86, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 20, y: 20, width: 984, height: 984), xRadius: 210, yRadius: 210).fill()
NSColor.white.setFill()
NSBezierPath(roundedRect: NSRect(x: 230, y: 170, width: 564, height: 684), xRadius: 56, yRadius: 56).fill()
NSColor(calibratedWhite: 0.13, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 320, y: 723, width: 380, height: 22), xRadius: 8, yRadius: 8).fill()
let widths = [9, 18, 9, 27, 9, 18, 18, 9, 27, 9, 9, 18, 27, 9, 18, 9]
var x: CGFloat = 303
for width in widths {
    NSBezierPath(rect: NSRect(x: x, y: 350, width: CGFloat(width), height: 270)).fill()
    x += CGFloat(width + 10)
}
NSColor(calibratedWhite: 0.40, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 348, y: 265, width: 328, height: 20), xRadius: 7, yRadius: 7).fill()
NSGraphicsContext.restoreGraphicsState()
let image = bitmap.cgImage!
for pixels in [16, 32, 64, 128, 256, 512, 1024] {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: pixels * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    let cg = ctx.makeImage()!
    let names: [String]
    switch pixels {
    case 16: names = ["icon_16x16.png"]
    case 32: names = ["icon_16x16@2x.png", "icon_32x32.png"]
    case 64: names = ["icon_32x32@2x.png"]
    case 128: names = ["icon_128x128.png"]
    case 256: names = ["icon_128x128@2x.png", "icon_256x256.png"]
    case 512: names = ["icon_256x256@2x.png", "icon_512x512.png"]
    default: names = ["icon_512x512@2x.png"]
    }
    for name in names {
        let dest = CGImageDestinationCreateWithURL(out.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cg, nil)
        guard CGImageDestinationFinalize(dest) else { fatalError("Could not write icon") }
    }
}

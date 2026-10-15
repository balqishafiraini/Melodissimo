// Usage: imgdiff <a.png> <b.png> [heat.png]
// Prints the percentage of pixels that differ clearly between two same-size screenshots, ignoring the status bar
// strip (the clock changes) and writes an optional heat map (differences in red over a dimmed copy of `b`).
// Animations (Alpanica's idle bob, confetti) cause small differences; a layout change shows up as a big one.
// Build: swiftc -O imgdiff.swift -o imgdiff
import AppKit

func pixels(_ path: String) -> (data: [UInt8], width: Int, height: Int)? {
    guard let image = NSImage(contentsOfFile: path),
          let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
    let width = cg.width, height = cg.height
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let context = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    context.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
    return (data, width, height)
}

let args = CommandLine.arguments
guard args.count >= 3, let a = pixels(args[1]), let b = pixels(args[2]) else {
    print("usage: imgdiff <a.png> <b.png> [heat.png]   (could not read an image)")
    exit(2)
}
guard a.width == b.width, a.height == b.height else {
    print("size differs: \(a.width)x\(a.height) vs \(b.width)x\(b.height)")
    exit(3)
}
let skipTop = Int(Double(a.height) * 0.035)
var differing = 0
var heat = b.data
var counted = 0
for y in 0..<a.height {
    for x in 0..<a.width {
        let i = (y * a.width + x) * 4
        if y < skipTop { heat[i] /= 3; heat[i + 1] /= 3; heat[i + 2] /= 3; continue }
        counted += 1
        let d = max(abs(Int(a.data[i]) - Int(b.data[i])), abs(Int(a.data[i + 1]) - Int(b.data[i + 1])), abs(Int(a.data[i + 2]) - Int(b.data[i + 2])))
        if d > 28 {
            differing += 1
            heat[i] = 255; heat[i + 1] = 0; heat[i + 2] = 0
        } else {
            heat[i] = UInt8(Int(heat[i]) * 2 / 5 + 120); heat[i + 1] = UInt8(Int(heat[i + 1]) * 2 / 5 + 120); heat[i + 2] = UInt8(Int(heat[i + 2]) * 2 / 5 + 120)
        }
    }
}
print(String(format: "%.2f", 100.0 * Double(differing) / Double(max(counted, 1))))
if args.count >= 4 {
    var out = heat
    let context = out.withUnsafeMutableBytes { raw in
        CGContext(data: raw.baseAddress, width: a.width, height: a.height, bitsPerComponent: 8, bytesPerRow: a.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
    if let cg = context?.makeImage() {
        let rep = NSBitmapImageRep(cgImage: cg)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[3]))
    }
}

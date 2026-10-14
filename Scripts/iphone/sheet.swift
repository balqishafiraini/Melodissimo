// Usage: sheet <out.png> <columns> <tileWidth> <image> [<image> ...]
// Lays screenshots out in a grid, each labelled with its parent folder and file name, so several devices
// (or several screens) can be checked in one picture. Build: swiftc -O sheet.swift -o sheet
import AppKit

let args = CommandLine.arguments
guard args.count >= 5, let columns = Int(args[2]), let tileWidth = Double(args[3]) else {
    print("usage: sheet <out.png> <columns> <tileWidth> <image>...")
    exit(1)
}
let paths = Array(args[4...])
let labelHeight = 22.0
let gap = 8.0

let images: [(String, NSImage)] = paths.compactMap { path in
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    let url = URL(fileURLWithPath: path)
    return ("\(url.deletingLastPathComponent().lastPathComponent)/\(url.deletingPathExtension().lastPathComponent)", image)
}
let tileHeights = images.map { tileWidth * Double($0.1.size.height) / Double($0.1.size.width) }
let rows = (images.count + columns - 1) / columns
var rowHeights: [Double] = []
for row in 0..<rows {
    let slice = tileHeights[(row * columns)..<min(images.count, (row + 1) * columns)]
    rowHeights.append((slice.max() ?? 0) + labelHeight)
}
let width = Double(columns) * (tileWidth + gap) + gap
let height = rowHeights.reduce(gap) { $0 + $1 + gap }

let canvas = NSImage(size: NSSize(width: width, height: height))
canvas.lockFocus()
NSColor(white: 0.15, alpha: 1).setFill()
NSRect(x: 0, y: 0, width: width, height: height).fill()
var y = height - gap
for row in 0..<rows {
    y -= rowHeights[row]
    for column in 0..<columns {
        let index = row * columns + column
        guard index < images.count else { break }
        let x = gap + Double(column) * (tileWidth + gap)
        let tileHeight = tileHeights[index]
        images[index].1.draw(in: NSRect(x: x, y: y + labelHeight + (rowHeights[row] - labelHeight - tileHeight), width: tileWidth, height: tileHeight),
                             from: .zero, operation: .copy, fraction: 1)
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.white]
        NSAttributedString(string: images[index].0, attributes: attributes).draw(at: NSPoint(x: x + 2, y: y + 2))
    }
    y -= gap
}
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: args[1]))

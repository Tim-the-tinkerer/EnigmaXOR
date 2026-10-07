#!/usr/bin/env swift
import AppKit
import Foundation

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let background = NSColor(calibratedRed: 0.10, green: 0.13, blue: 0.18, alpha: 1)
background.setFill()
NSBezierPath(ovalIn: NSRect(x: 40, y: 40, width: 944, height: 944)).fill()

let ring = NSColor(calibratedRed: 0.93, green: 0.62, blue: 0.22, alpha: 1)
ring.setStroke()
let outer = NSBezierPath(ovalIn: NSRect(x: 120, y: 120, width: 784, height: 784))
outer.lineWidth = 20
outer.stroke()

let inner = NSBezierPath(ovalIn: NSRect(x: 300, y: 300, width: 424, height: 424))
inner.lineWidth = 16
inner.stroke()

let text = "⊕" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.monospacedSystemFont(ofSize: 360, weight: .bold),
    .foregroundColor: ring
]
let textSize = text.size(withAttributes: attributes)
text.draw(
    at: NSPoint(x: (CGFloat(size) - textSize.width) / 2, y: (CGFloat(size) - textSize.height) / 2 - 20),
    withAttributes: attributes
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Failed to create icon\n", stderr)
    exit(1)
}

let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = cwd.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
let output = assets.appendingPathComponent("AppIcon-1024.png")
try png.write(to: output)
print("Wrote \(output.path)")

#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate-icon.swift <AppIcon.appiconset>\n", stderr)
    exit(2)
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let outputs: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func drawIcon(size: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "RoundelIcon", code: 1)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext
    defer { NSGraphicsContext.restoreGraphicsState() }

    let context = graphicsContext.cgContext
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let inset = CGFloat(size) * 0.07
    let cornerRadius = CGFloat(size) * 0.22
    let tile = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: CGFloat(size) - inset * 2, height: CGFloat(size) - inset * 2),
        xRadius: cornerRadius,
        yRadius: cornerRadius
    )
    NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1).setFill()
    tile.fill()

    let ringColor = NSColor(calibratedRed: 0.99, green: 0.42, blue: 0.36, alpha: 1)
    let quietColor = NSColor.white.withAlphaComponent(0.9)
    let radius = CGFloat(size) * 0.066
    let spacing = CGFloat(size) * 0.19
    let center = CGFloat(size) / 2

    for row in -1...1 {
        for column in -1...1 {
            let point = NSPoint(
                x: center + CGFloat(column) * spacing,
                y: center + CGFloat(row) * spacing
            )
            let dotRect = NSRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            let dot = NSBezierPath(ovalIn: dotRect)
            ((row == 0 && column == 0) ? ringColor : quietColor).setFill()
            dot.fill()
        }
    }

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RoundelIcon", code: 2)
    }
    return png
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for (name, size) in outputs {
    try drawIcon(size: size).write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
}

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

/// The icon is the mark the app makes: one red ring, the same one a marked day
/// wears in the calendar, on the app's own near-black.
///
/// Proportions follow Apple's macOS icon grid — the rounded square covers 80% of
/// the canvas, with a corner radius of 22.5% of that square — so Roundel sits
/// level with the rest of the Dock rather than looking slightly too round.
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

    let canvas = CGFloat(size)
    let inset = canvas * 0.10
    let tileSide = canvas - inset * 2
    let tile = NSBezierPath(
        roundedRect: NSRect(x: inset, y: inset, width: tileSide, height: tileSide),
        xRadius: tileSide * 0.225,
        yRadius: tileSide * 0.225
    )
    NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
    tile.fill()

    // Apple's dark-mode system red, which is what the calendar actually draws.
    let ringColor = NSColor(calibratedRed: 1.0, green: 0.27, blue: 0.23, alpha: 1)

    // Proportionally heavier than the 30pt calendar cell: a stroke that thin
    // disappears at 16px, where the icon still has to read as a ring.
    let strokeWidth = canvas * 0.075
    let diameter = canvas * 0.56
    let ringRect = NSRect(
        x: (canvas - diameter) / 2,
        y: (canvas - diameter) / 2,
        width: diameter,
        height: diameter
    )

    // Left hollow. The calendar tints a marked day at six per cent, which is
    // almost nothing; anything heavier here reads as a filled disc instead of a
    // day with a ring around it.
    let ring = NSBezierPath(ovalIn: ringRect.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
    ring.lineWidth = strokeWidth
    ringColor.setStroke()
    ring.stroke()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "RoundelIcon", code: 2)
    }
    return png
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for (name, size) in outputs {
    try drawIcon(size: size).write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
}

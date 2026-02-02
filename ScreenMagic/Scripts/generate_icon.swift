#!/usr/bin/env swift

import AppKit

// Generate app icon from SF Symbol "camera.viewfinder"
func generateIcon() {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    let iconsetPath = "build/AppIcon.iconset"
    
    // Create iconset directory
    try? FileManager.default.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true)
    
    for size in sizes {
        // Generate 1x
        if let image = createIconImage(size: size) {
            saveImage(image, to: "\(iconsetPath)/icon_\(size)x\(size).png")
        }
        // Generate 2x (for sizes up to 512)
        if size <= 512 {
            if let image = createIconImage(size: size * 2) {
                saveImage(image, to: "\(iconsetPath)/icon_\(size)x\(size)@2x.png")
            }
        }
    }
    
    print("Icon images generated in \(iconsetPath)")
}

func createIconImage(size: Int) -> NSImage? {
    let imageSize = NSSize(width: size, height: size)
    let image = NSImage(size: imageSize)
    
    image.lockFocus()
    
    // Draw gradient background
    let rect = NSRect(origin: .zero, size: imageSize)
    
    // Draw rounded rectangle background - solid red
    let cornerRadius = CGFloat(size) * 0.2
    let path = NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: cornerRadius, yRadius: cornerRadius)
    NSColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0).setFill()
    path.fill()
    
    // Draw the SF Symbol in white
    let symbolSize = CGFloat(size) * 0.6
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: symbolSize, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfig) {
        
        // Create a white-tinted version of the symbol
        let tintedSymbol = NSImage(size: symbol.size)
        tintedSymbol.lockFocus()
        NSColor.white.set()
        let symbolBounds = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: symbolBounds)
        symbolBounds.fill(using: .sourceAtop)
        tintedSymbol.unlockFocus()
        
        let symbolRect = NSRect(
            x: (CGFloat(size) - symbolSize) / 2,
            y: (CGFloat(size) - symbolSize) / 2,
            width: symbolSize,
            height: symbolSize
        )
        
        tintedSymbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1.0)
    }
    
    image.unlockFocus()
    
    return image
}

func saveImage(_ image: NSImage, to path: String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }
    
    try? pngData.write(to: URL(fileURLWithPath: path))
}

generateIcon()

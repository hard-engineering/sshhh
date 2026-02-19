import Cocoa

func generateIcon(name: String, text: String, outputName: String) {
    let size = CGSize(width: 1024, height: 1024)
    let outputURL = URL(fileURLWithPath: outputName)

    // Create image context
    let image = NSImage(size: size)
    image.lockFocus()

    // 1. Background (Rounded Rectangle with Gradient)
    let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size), xRadius: 200, yRadius: 200)
    let gradient = NSGradient(starting: NSColor(red: 0.2, green: 0.0, blue: 0.4, alpha: 1.0), // Dark Purple
                              ending: NSColor(red: 0.5, green: 0.1, blue: 0.8, alpha: 1.0))   // Lighter Purple
    gradient?.draw(in: path, angle: -45)

    // 2. Text/Emoji
    let font = NSFont.systemFont(ofSize: 600)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]

    let attributedString = NSAttributedString(string: text, attributes: attributes)
    let textSize = attributedString.size()
    let textRect = NSRect(
        x: (size.width - textSize.width) / 2,
        y: (size.height - textSize.height) / 2 + 50, // Slight offset
        width: textSize.width,
        height: textSize.height
    )

    attributedString.draw(in: textRect)

    image.unlockFocus()

    // Save to disk
    if let tiffData = image.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiffData),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        try? pngData.write(to: outputURL)
        print("✅ Created \(outputName)")
    }
}

// Generate Icons
generateIcon(name: "AppIcon", text: "🤫", outputName: "AppIcon.png")
generateIcon(name: "SpeakingIcon", text: "🗣️", outputName: "SpeakingIcon.png")

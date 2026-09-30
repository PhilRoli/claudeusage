#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$REPO/Packaging/AppIcon.iconset"
RENDER_SCRIPT="$(mktemp /tmp/render_icon.XXXXXX.swift)"

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

cat > "$RENDER_SCRIPT" <<'SWIFT'
import AppKit

let sizes: [(Int, String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
]

let outputDir = CommandLine.arguments[1]

for (size, name) in sizes {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    let font = NSFont.systemFont(ofSize: CGFloat(size) * 0.72)
    let attrs: [NSAttributedString.Key: Any] = [.font: font]
    let str = NSAttributedString(string: "📊", attributes: attrs)
    let strSize = str.size()
    let point = NSPoint(x: (CGFloat(size) - strSize.width) / 2, y: (CGFloat(size) - strSize.height) / 2)
    str.draw(at: point)
    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { fatalError("Failed to render \(name)") }

    let url = URL(fileURLWithPath: outputDir).appendingPathComponent("\(name).png")
    try png.write(to: url)
}
SWIFT

swift "$RENDER_SCRIPT" "$ICONSET"
rm -f "$RENDER_SCRIPT"

iconutil -c icns "$ICONSET" -o "$REPO/Packaging/AppIcon.icns"
rm -rf "$ICONSET"

echo "Wrote Packaging/AppIcon.icns"

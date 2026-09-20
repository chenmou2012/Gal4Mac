#!/usr/bin/env swift
// 生成 Gal4Mac App Icon
// 输出 1024x1024 PNG 到指定路径

import AppKit
import Foundation

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)

image.lockFocus()

let rect = NSRect(origin: .zero, size: size)
let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40),
                          xRadius: 200, yRadius: 200)

// 渐变背景
let gradient = NSGradient(colors: [
    NSColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1.0),  // 紫色
    NSColor(red: 0.85, green: 0.30, blue: 0.55, alpha: 1.0)   // 粉色
])
gradient?.draw(in: bgPath, angle: -45)

// 高光
let highlightRect = NSRect(x: 80, y: 600, width: 864, height: 300)
let highlight = NSGradient(colors: [
    NSColor.white.withAlphaComponent(0.25),
    NSColor.white.withAlphaComponent(0.0)
])
highlight?.draw(in: highlightRect, angle: -90)

// 中央文字 "G4M"
let text = "G4M"
let attrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 360, weight: .heavy),
    .foregroundColor: NSColor.white
]
let attrStr = NSAttributedString(string: text, attributes: attrs)
let textSize = attrStr.size()
let textPoint = NSPoint(
    x: (size.width - textSize.width) / 2,
    y: (size.height - textSize.height) / 2 - 30
)
attrStr.draw(at: textPoint)

// 副标题
let subtitle = "gal4mac"
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 64, weight: .medium),
    .foregroundColor: NSColor.white.withAlphaComponent(0.85)
]
let subtitleStr = NSAttributedString(string: subtitle, attributes: subtitleAttrs)
let subtitleSize = subtitleStr.size()
let subtitlePoint = NSPoint(
    x: (size.width - subtitleSize.width) / 2,
    y: textPoint.y - 90
)
subtitleStr.draw(at: subtitlePoint)

// 顶部装饰星
let starAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 100),
    .foregroundColor: NSColor.white.withAlphaComponent(0.9)
]
let starStr = NSAttributedString(string: "✦ ✦ ✦", attributes: starAttrs)
let starSize = starStr.size()
let starPoint = NSPoint(
    x: (size.width - starSize.width) / 2,
    y: size.height - 250
)
starStr.draw(at: starPoint)

image.unlockFocus()

// 保存为 PNG
let args = CommandLine.arguments
let outputPath = args.count > 1 ? args[1] : "/tmp/gal4mac_icon.png"

if let tiffData = image.tiffRepresentation,
   let bitmap = NSBitmapImageRep(data: tiffData),
   let pngData = bitmap.representation(using: .png, properties: [:]) {
    try? pngData.write(to: URL(fileURLWithPath: outputPath))
    print("✓ Icon saved to \(outputPath)")
}

#!/usr/bin/env swift
import CoreGraphics
import AppKit
import Foundation

func createIcon(size: Int, outputPath: String) {
    let width = size
    let height = size
    let scale: CGFloat = 1.0
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return }
    
    context.scaleBy(x: scale, y: scale)
    let s = CGFloat(size)
    
    // 背景渐变
    let gradientColors = [
        CGColor(red: 0.357, green: 0.498, blue: 1.0, alpha: 1.0),
        CGColor(red: 0.486, green: 0.361, blue: 1.0, alpha: 1.0)
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: gradientColors, locations: locations)!
    
    // 圆角矩形背景
    let radius = s * 0.22
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])
    context.resetClip()
    
    // 大相机图标区域 - 主照片框
    let frameW = s * 0.58
    let frameH = s * 0.50
    let frameX = s * 0.14
    let frameY = s * 0.20
    let frameRadius = s * 0.07
    
    // 主相框 - 白色半透明
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    let mainFrame = CGPath(roundedRect: CGRect(x: frameX, y: frameY, width: frameW, height: frameH),
                          cornerWidth: frameRadius, cornerHeight: frameRadius, transform: nil)
    context.addPath(mainFrame)
    context.fillPath()
    
    // 内部照片内容 - 蓝色背景
    let innerMargin = s * 0.025
    context.setFillColor(CGColor(red: 0.91, green: 0.93, blue: 1.0, alpha: 1.0))
    let innerFrame = CGPath(roundedRect: CGRect(x: frameX + innerMargin, y: frameY + innerMargin,
                                                 width: frameW - 2 * innerMargin, height: frameH - 2 * innerMargin),
                           cornerWidth: frameRadius * 0.7, cornerHeight: frameRadius * 0.7, transform: nil)
    context.addPath(innerFrame)
    context.fillPath()
    
    // 太阳/圆圈 - 代表天空
    let sunR = s * 0.09
    let sunX = frameX + innerMargin + sunR + s * 0.06
    let sunY = frameY + innerMargin + sunR + s * 0.06
    context.setFillColor(CGColor(red: 1.0, green: 0.84, blue: 0.2, alpha: 1.0))
    context.fillEllipse(in: CGRect(x: sunX - sunR, y: sunY - sunR, width: sunR * 2, height: sunR * 2))
    
    // 山形
    let mtnY = frameY + frameH - innerMargin
    let mtnBaseY = mtnY - s * 0.02
    let mtnPath = CGMutablePath()
    mtnPath.move(to: CGPoint(x: frameX + innerMargin, y: mtnBaseY))
    mtnPath.addLine(to: CGPoint(x: frameX + frameW * 0.32, y: frameY + frameH * 0.38))
    mtnPath.addLine(to: CGPoint(x: frameX + frameW * 0.52, y: frameY + frameH * 0.60))
    mtnPath.addLine(to: CGPoint(x: frameX + frameW * 0.70, y: frameY + frameH * 0.30))
    mtnPath.addLine(to: CGPoint(x: frameX + frameW - innerMargin, y: frameY + frameH * 0.55))
    mtnPath.addLine(to: CGPoint(x: frameX + frameW - innerMargin, y: mtnBaseY))
    mtnPath.closeSubpath()
    context.setFillColor(CGColor(red: 0.357, green: 0.498, blue: 1.0, alpha: 0.85))
    context.addPath(mtnPath)
    context.fillPath()
    
    // 小垃圾桶图标 - 右下角
    let trashSize = s * 0.28
    let trashX = s * 0.60
    let trashY = s * 0.56
    
    // 垃圾桶背景卡片
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.95))
    let trashCard = CGPath(roundedRect: CGRect(x: trashX, y: trashY, width: trashSize, height: trashSize),
                          cornerWidth: trashSize * 0.15, cornerHeight: trashSize * 0.15, transform: nil)
    context.addPath(trashCard)
    context.fillPath()
    
    // 垃圾桶图形
    let tc = CGPoint(x: trashX + trashSize / 2, y: trashY + trashSize / 2)
    let tw = trashSize * 0.38
    let th = trashSize * 0.40
    
    // 垃圾桶盖子
    context.setFillColor(CGColor(red: 1.0, green: 0.42, blue: 0.42, alpha: 1.0))
    let lidRect = CGRect(x: tc.x - tw * 0.6, y: tc.y - th * 0.6, width: tw * 1.2, height: th * 0.22)
    context.fill(lidRect)
    
    // 盖子把手
    let handleRect = CGRect(x: tc.x - tw * 0.22, y: tc.y - th * 0.6 - th * 0.16, width: tw * 0.44, height: th * 0.18)
    context.fill(handleRect)
    
    // 垃圾桶身体
    let bodyPath = CGMutablePath()
    bodyPath.move(to: CGPoint(x: tc.x - tw * 0.55, y: tc.y - th * 0.35))
    bodyPath.addLine(to: CGPoint(x: tc.x + tw * 0.55, y: tc.y - th * 0.35))
    bodyPath.addLine(to: CGPoint(x: tc.x + tw * 0.44, y: tc.y + th * 0.50))
    bodyPath.addLine(to: CGPoint(x: tc.x - tw * 0.44, y: tc.y + th * 0.50))
    bodyPath.closeSubpath()
    context.addPath(bodyPath)
    context.fillPath()
    
    // 垃圾桶条纹（白色线条）
    context.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.9))
    context.setLineWidth(tw * 0.12)
    context.setLineCap(.round)
    // 左条
    context.move(to: CGPoint(x: tc.x - tw * 0.2, y: tc.y - th * 0.20))
    context.addLine(to: CGPoint(x: tc.x - tw * 0.2, y: tc.y + th * 0.38))
    context.strokePath()
    // 中条
    context.move(to: CGPoint(x: tc.x, y: tc.y - th * 0.20))
    context.addLine(to: CGPoint(x: tc.x, y: tc.y + th * 0.38))
    context.strokePath()
    // 右条
    context.move(to: CGPoint(x: tc.x + tw * 0.2, y: tc.y - th * 0.20))
    context.addLine(to: CGPoint(x: tc.x + tw * 0.2, y: tc.y + th * 0.38))
    context.strokePath()
    
    // 滑动手势箭头 - 底部提示
    let arrowY = s * 0.88
    let arrowCX = s * 0.50
    context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.6))
    // 向右箭头
    let arrowW = s * 0.22
    let arrowH = s * 0.04
    context.fill(CGRect(x: arrowCX - arrowW/2, y: arrowY - arrowH/2, width: arrowW, height: arrowH))
    
    // 保存图像
    guard let cgImage = context.makeImage() else { return }
    let nsImage = NSBitmapImageRep(cgImage: cgImage)
    guard let pngData = nsImage.representation(using: .png, properties: [:]) else { return }
    
    let url = URL(fileURLWithPath: outputPath)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try? pngData.write(to: url)
    print("✓ \(url.lastPathComponent) (\(size)x\(size))")
}

let projectRoot = CommandLine.arguments[0]
    .components(separatedBy: "/scripts/")[0]

let sizes: [(Int, String)] = [
    // iOS
    (20,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"),
    (40,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"),
    (60,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"),
    (29,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"),
    (58,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"),
    (87,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"),
    (40,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"),
    (80,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"),
    (120,  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"),
    (120,  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"),
    (180,  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"),
    (76,   "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"),
    (152,  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"),
    (167,  "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"),
    (1024, "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"),
    // Android
    (48,   "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"),
    (72,   "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"),
    (96,   "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"),
    (144,  "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"),
    (192,  "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"),
    // Web
    (192,  "web/icons/Icon-192.png"),
    (512,  "web/icons/Icon-512.png"),
    (192,  "web/icons/Icon-maskable-192.png"),
    (512,  "web/icons/Icon-maskable-512.png"),
    // Source icon
    (1024, "assets/icons/app_icon.png"),
]

print("生成 PhotoSwipe 应用图标...\n")
for (size, relativePath) in sizes {
    let fullPath = projectRoot + "/" + relativePath
    createIcon(size: size, outputPath: fullPath)
}
print("\n✅ 图标生成完成!")

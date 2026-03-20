#!/usr/bin/env python3
"""
生成 PhotoSwipe 应用图标 - 使用 PIL 直接绘制
"""

from PIL import Image, ImageDraw
from pathlib import Path
import os

def create_icon(size, output_path):
    """创建指定尺寸的应用图标"""
    # 创建图像
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # 背景渐变（使用近似方法）
    for y in range(size):
        # 蓝紫渐变
        r = int(91 + (124 - 91) * (y / size))
        g = int(127 + (92 - 127) * (y / size))
        b = int(255 + (255 - 255) * (y / size))
        draw.line([(0, y), (size, y)], fill=(r, g, b, 255))
    
    # 内圆（半透明白色）
    margin = int(size * 0.1)
    draw.ellipse(
        [(margin, margin), (size - margin, size - margin)],
        outline=(255, 255, 255, 25),
        width=int(size * 0.02)
    )
    
    # 绘制四个照片框架
    frame_size = int(size * 0.25)
    frame_margin = int(size * 0.08)
    
    # 照片框架位置
    positions = [
        (frame_margin, frame_margin),  # 左上
        (size - frame_margin - frame_size, frame_margin),  # 右上
        (frame_margin, size - frame_margin - frame_size),  # 左下
        (size - frame_margin - frame_size, size - frame_margin - frame_size),  # 右下
    ]
    
    colors = [
        ((91, 127, 255), (232, 238, 255)),  # 蓝色
        ((255, 107, 107), (255, 232, 232)),  # 红色
        ((6, 168, 125), (78, 205, 196)),  # 绿色
        ((255, 232, 232), (255, 138, 128)),  # 浅红
    ]
    
    for i, (x, y) in enumerate(positions):
        # 外框（白色）
        draw.rounded_rectangle(
            [(x, y), (x + frame_size, y + frame_size)],
            radius=int(frame_size * 0.15),
            fill=(255, 255, 255, 242)
        )
        
        # 内框（背景色）
        inner_margin = int(frame_size * 0.08)
        inner_x = x + inner_margin
        inner_y = y + inner_margin
        inner_size = frame_size - 2 * inner_margin
        
        draw.rounded_rectangle(
            [(inner_x, inner_y), (inner_x + inner_size, inner_y + inner_size)],
            radius=int(inner_size * 0.15),
            fill=colors[i][1]
        )
        
        # 绘制照片内容（简化版）
        if i < 3:
            # 前三个是照片
            circle_r = int(inner_size * 0.2)
            circle_x = inner_x + inner_size // 2
            circle_y = inner_y + inner_size // 3
            draw.ellipse(
                [(circle_x - circle_r, circle_y - circle_r),
                 (circle_x + circle_r, circle_y + circle_r)],
                fill=colors[i][0]
            )
            
            # 简单的山形
            mountain_y = inner_y + inner_size * 0.6
            points = [
                (inner_x + inner_size * 0.2, mountain_y + inner_size * 0.2),
                (inner_x + inner_size * 0.4, mountain_y),
                (inner_x + inner_size * 0.6, mountain_y + inner_size * 0.15),
                (inner_x + inner_size * 0.8, mountain_y - inner_size * 0.1),
                (inner_x + inner_size * 0.8, mountain_y + inner_size * 0.2),
                (inner_x + inner_size * 0.2, mountain_y + inner_size * 0.2),
            ]
            draw.polygon(points, fill=colors[i][0])
        else:
            # 第四个是垃圾桶
            trash_x = inner_x + inner_size // 2
            trash_y = inner_y + inner_size // 2
            trash_size = int(inner_size * 0.3)
            
            # 垃圾桶盖
            draw.rectangle(
                [(trash_x - trash_size * 0.6, trash_y - trash_size * 0.8),
                 (trash_x + trash_size * 0.6, trash_y - trash_size * 0.6)],
                fill=colors[i][0]
            )
            
            # 垃圾桶身
            draw.polygon(
                [(trash_x - trash_size * 0.5, trash_y - trash_size * 0.5),
                 (trash_x + trash_size * 0.5, trash_y - trash_size * 0.5),
                 (trash_x + trash_size * 0.4, trash_y + trash_size * 0.5),
                 (trash_x - trash_size * 0.4, trash_y + trash_size * 0.5)],
                fill=colors[i][0]
            )
    
    # 中心装饰圆
    center_r = int(size * 0.08)
    draw.ellipse(
        [(size // 2 - center_r, size // 2 - center_r),
         (size // 2 + center_r, size // 2 + center_r)],
        fill=(255, 255, 255, 38)
    )
    
    # 保存图像
    output_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(output_path, 'PNG')
    print(f"✓ {output_path.name} ({size}x{size})")

def main():
    project_root = Path(__file__).parent.parent
    
    # iOS 图标
    print("生成 iOS 图标...")
    ios_sizes = [
        (20, 'Icon-App-20x20@1x.png'),
        (40, 'Icon-App-20x20@2x.png'),
        (60, 'Icon-App-20x20@3x.png'),
        (29, 'Icon-App-29x29@1x.png'),
        (58, 'Icon-App-29x29@2x.png'),
        (87, 'Icon-App-29x29@3x.png'),
        (40, 'Icon-App-40x40@1x.png'),
        (80, 'Icon-App-40x40@2x.png'),
        (120, 'Icon-App-40x40@3x.png'),
        (120, 'Icon-App-60x60@2x.png'),
        (180, 'Icon-App-60x60@3x.png'),
        (76, 'Icon-App-76x76@1x.png'),
        (152, 'Icon-App-76x76@2x.png'),
        (167, 'Icon-App-83.5x83.5@2x.png'),
        (1024, 'Icon-App-1024x1024@1x.png'),
    ]
    
    ios_dir = project_root / 'ios' / 'Runner' / 'Assets.xcassets' / 'AppIcon.appiconset'
    for size, filename in ios_sizes:
        create_icon(size, ios_dir / filename)
    
    # Android 图标
    print("\n生成 Android 图标...")
    android_sizes = [
        (48, 'mipmap-mdpi/ic_launcher.png'),
        (72, 'mipmap-hdpi/ic_launcher.png'),
        (96, 'mipmap-xhdpi/ic_launcher.png'),
        (144, 'mipmap-xxhdpi/ic_launcher.png'),
        (192, 'mipmap-xxxhdpi/ic_launcher.png'),
    ]
    
    android_dir = project_root / 'android' / 'app' / 'src' / 'main' / 'res'
    for size, rel_path in android_sizes:
        create_icon(size, android_dir / rel_path)
    
    # Web 图标
    print("\n生成 Web 图标...")
    web_sizes = [
        (192, 'Icon-192.png'),
        (512, 'Icon-512.png'),
    ]
    
    web_dir = project_root / 'web' / 'icons'
    for size, filename in web_sizes:
        create_icon(size, web_dir / filename)
    
    print("\n✅ 所有图标生成完成!")

if __name__ == '__main__':
    main()

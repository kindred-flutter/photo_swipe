# PhotoSwipe - 照片清理应用

一个简洁高效的 Flutter 照片管理应用，支持手势快速删除、软垃圾箱管理和统计展示。

## 功能特性

- 📱 **可视化浏览** - 3 列网格展示照片
- 👆 **手势删除** - 左下到右上的对角线手势快速移入垃圾箱
- 🗑 **软垃圾箱** - 30 天自动清理，支持恢复
- 📊 **统计条** - 实时显示照片数、垃圾箱数、已节省空间
- 📋 **照片信息** - 查看文件大小、分辨率、拍摄时间
- 🌓 **深色模式** - 自动跟随系统主题

## 快速开始

### 环境要求

- Flutter 3.0+
- Dart 3.0+
- iOS 12.0+ / Android 6.0+

### 安装依赖

```bash
flutter pub get
```

### 运行应用

```bash
flutter run
```

### 构建发布

```bash
# iOS
flutter build ios

# Android
flutter build apk
```

## 项目结构

```
lib/
├── main.dart              # 应用入口
├── app.dart               # 应用配置
├── core/                  # 核心模块
│   ├── constants/         # 常量定义
│   ├── theme/             # 主题配置
│   ├── utils/             # 工具函数
│   └── extensions/        # 扩展方法
├── data/                  # 数据层
│   ├── models/            # 数据模型
│   ├── repositories/      # 仓储层
│   └── datasources/       # 数据源
├── presentation/          # 展示层
│   ├── screens/           # 屏幕页面
│   ├── widgets/           # 通用组件
│   └── providers/         # 状态管理
└── services/              # 服务层
```

## 核心功能实现

### 1. 照片管理
- 从系统相册导入照片
- 本地数据库存储照片元数据
- 支持缩略图缓存

### 2. 手势识别
- 监听触摸事件
- 验证左下到右上的对角线轨迹
- 实时绘制删除轨迹

### 3. 垃圾箱管理
- 软删除到垃圾箱（30 天后自动清理）
- 支持恢复和永久删除
- 显示删除时间和过期倒计时

### 4. 数据统计
- 实时计算总照片数
- 统计垃圾箱中的照片数
- 计算已节省的存储空间

## 技术栈

- **状态管理**: Provider
- **本地存储**: SQLite
- **照片管理**: photo_manager
- **UI 框架**: Material Design 3
- **工具库**: uuid, intl, permission_handler

## 开发进度

- [x] 项目初始化
- [x] 数据层实现
- [x] 基础 UI 框架
- [ ] 手势识别系统
- [ ] 照片预览功能
- [ ] 动画优化
- [ ] 性能测试

## 许可证

MIT License

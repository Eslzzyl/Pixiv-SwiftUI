<div align="center">

<!-- App Icon with shadow and rounded corners -->
<p align="center">
  <img src="./docs/images/AppIcon.png" alt="Pixiv-SwiftUI Icon" width="128" style="border-radius: 24px; box-shadow: 0 4px 24px rgba(0,0,0,0.15);">
</p>

<h1 align="center" style="margin-top: 16px;">Pixiv-SwiftUI</h1>

<p align="center">一个基于 SwiftUI 的 Pixiv 第三方客户端</p>

<!-- Badges -->
<p align="center">
  <img src="https://img.shields.io/badge/iOS-blue.svg?style=flat-square&logo=apple" alt="iOS">
  <img src="https://img.shields.io/badge/iPadOS-blue.svg?style=flat-square&logo=apple" alt="iPadOS">
  <img src="https://img.shields.io/badge/macOS-blue.svg?style=flat-square&logo=apple" alt="macOS">
  <img src="https://img.shields.io/badge/License-AGPL--3.0-green.svg?style=flat-square" alt="License">
</p>

<p align="center">
  <a href="README_en.md">English</a> | 简体中文
</p>

</div>

---

> **声明**  
> 这是一个实验性的 Vibe Coding 项目：项目的**所有**代码均由大语言模型生成。开发者会尽力进行测试，但不能保证项目的可靠性。

---

## 功能特性

### 插画与漫画

- 推荐流：推荐和热门内容
- 排行榜：每日、每周、每月及性别分类排行榜
- 动图支持：ugoira 动图，允许设置自动播放和手动播放
- 收藏管理：公开/私密收藏
- 评论系统：查看和回复评论
- 用户主页：插画、漫画、小说、关注列表、用户信息

### 小说

- 推荐与排行榜
- 阅读器：流畅的阅读体验，支持进度记录
- 沉浸式翻译：可配置的翻译服务，支持双语对照
- 系列管理：小说系列浏览与阅读

### 搜索功能

- 综合搜索：插画、小说、用户一站式搜索
- 亮点：展示 pixivison 网站定期推出的特辑内容
- 趋势标签：热门标签展示
- 搜索历史：记录与快速访问

### 翻译功能

- 支持翻译插画标题、简介，小说标题、简介，用户简介和所有评论
- 多翻译服务支持：可配置主要/备用翻译服务
- 智能语言检测：自动识别内容语言
- 双语对照阅读模式
- 针对LLM在小说场景下的特别优化：提交多段结合上下文翻译

### 网络功能

- 直连模式：绕过 SNI 实现直连访问

### 下载与本地功能

- 图片下载：批量下载插画至相册
- 浏览历史：记录查看过的内容
- 数据导入/导出（兼容 pixez 格式）
- 实验性的插画收藏永久缓存：避免作者删图导致插画丢失

### 外观与体验

- 深色模式：自动/手动切换主题色
- 主题自定义：预设和自定义的强调色
- 布局适配：针对不同平台优化布局
- 缓存管理：图片缓存与存储清理
- 屏蔽设置：屏蔽标签、用户、具体插画
- R-18/R-18G/剧透/AI 过滤：正常显示、模糊显示、屏蔽、仅显示

## 系统要求

项目同时支持 iOS、iPadOS 和 macOS。

当前的支持情况：
- iOS 26 和 iOS 18：经过测试，可以正常工作。
- iOS 17：理论上支持，但没有经过测试。
- iPad OS：请参考 iOS。仅 iPadOS 26 经过了测试。
- macOS 26：经过测试，可以正常工作。
- macOS 14/15：理论上支持，但没有经过测试。

> 由于 SwiftData 的兼容性问题，App 不支持更旧的系统版本。

## 编译指南

如果你希望自行编译本项目，请确保你的开发环境满足以下要求：
- Xcode 16.0+
- Swift 6.0
- macOS 15.0+ (推荐)

### 1. 克隆仓库
```bash
git clone https://github.com/Eslzzyl/Pixiv-SwiftUI.git
cd Pixiv-SwiftUI
```

### 2. 准备资源文件 (关键)
项目依赖 `Resources/tags.json` 文件进行编译。如果该文件缺失，编译会报错。你可以通过以下任一方式准备该文件：

- **自动化生成**（推荐）：
  执行 `pixiv-tags` 目录下的导出脚本：
  ```bash
  cd pixiv-tags
  python3 export_tags.py
  cd ..
  ```
  该脚本会在数据库缺失时自动生成一个空的 `tags.json` 模版。

- **手动创建**：
  在项目根目录下手动创建一个包含基本结构的文件：
  ```bash
  mkdir -p Resources
  echo '{"timestamp": "2026-01-01T00:00:00", "tags": {}}' > Resources/tags.json
  ```

### 3. 使用 Xcode 编译
1. 双击打开 `Pixiv-SwiftUI.xcodeproj`。
2. 选择对应的 Scheme（Debug/Release）和平台 (iOS 或 macOS)。
3. 点击 `Build` (Cmd + B) 或 `Run` (Cmd + R)。

## 安装方式

- iOS/iPadOS：到 Release 中下载最新版本的 ipa 包并使用 AltStore 等方式侧载安装。
- macOS：到 Release 中下载最新版本的 dmg 包并安装。安装包没有签名，可以执行以下命令来绕过：

```shell
sudo xattr -rd com.apple.quarantine /Applications/Pixiv-SwiftUI.app
```

- macOS (Homebrew)：

```shell
brew tap thedavidweng/homebrew-tap
brew install --cask pixiv-swiftui
```

## 特别鸣谢

- [pixez-flutter](https://github.com/Notsfsssf/pixez-flutter): 这是本项目的主要参考对象，大量参考了该项目的 API 和 UI 设计。pixez-flutter 是一个非常优秀的项目，遗憾的是在 iOS 设备上的异常发热问题长期未获得解决，这也是本项目诞生的主要动机。
- [Kingfisher](https://github.com/onevcat/Kingfisher): 提供图片加载和缓存
- [GzipSwift](https://github.com/1024jp/GzipSwift): 直连模式手动实现了 HTTP 协议，GzipSwift 为其提供 gzip 解压功能。
- [SwiftSoup](https://github.com/scinfu/SwiftSoup)：为亮点和以图搜图功能提供了 HTML 解析能力
- [沉浸式翻译](https://immersivetranslate.com/zh-Hans/): 为项目的翻译功能提供了启发
- [pixivpy](https://github.com/upbit/pixivpy): 提供了 API 参考
- [OpenCode](https://opencode.ai/): OpenCode Zen 计划免费提供的模型实现了本项目的大部分代码
- [iFlow CLI](https://cli.iflow.cn/)：提供的免费模型参与实现了项目

参与开发的模型包括：
- MiniMax M2.1
- Kimi-K2.5
- GLM-4.6
- GLM-4.7
- GLM-5
- Qwen3.5-Plus
- Gemini 3 Flash
- Gemini 3 Pro
- Gemini 3.1 Pro
- Grok Code Fast 1
- GPT-5.2
- GPT-5.2-Codex
- GPT-5.3-Codex
- Claude Haiku 4.5
- Claude Opus 4.5
- Claude Sonnet 4.6

## 截图

截图可能无法完全反映最新的 UI 状态。

点击对应连接跳转到截图页查看。

[iOS](./docs/screenshots/ios.md) | iPadOS | [macOS](./docs/screenshots/macos.md)

---

**免责声明**: 本项目仅供学习研究使用，与 Pixiv 官方无任何关联。

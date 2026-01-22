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
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square&logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/License-AGPL--3.0-green.svg?style=flat-square" alt="License">
</p>

</div>

---

> **声明**  
> 这是一个实验性的 Vibe Coding 项目：项目的**所有**代码均由大语言模型生成。开发者会尽力进行测试，但不能保证项目的可靠性。

---

## 功能特性

- 插画部分该有的应该都有了，支持自行配置翻译服务来翻译简介、评论等内容
- 小说，带沉浸式翻译风格的翻译功能
- 漫画后续会添加
- 实验性的直连模式：支持绕过 SNI 实现直连。在 Network.framework 的基础上手动实现了 HTTP 协议。目前可能还有少量连接管理问题

## 系统要求

项目同时支持 iOS、iPadOS 和 macOS。

当前的支持情况：
- iOS 26.0 或更新版本：所有功能经过测试，可以正常工作。已知的 bug 除外。
- iOS 18：没有测试过，但是应该可以正常工作。
- iOS 16 - iOS 17：计划内支持，但目前不支持。
- 更旧的 iOS 版本：不提供支持。
- iPadOS 26.0 或更新版本：所有功能应当都正常工作，但预计存在一些布局问题。
- 更旧的 iPadOS 版本：请参考 iOS
- macOS 26.0 或更新版本：所有功能经过测试，可以正常工作。已知的 bug 除外。
- macOS 15：没有测试过，但是应该可以正常工作。
- macOS 14：计划内支持，但目前不支持。
- 更旧的 macOS 版本：不提供支持。

## 安装方式

- iOS/iPadOS：到 Release 中下载最新版本的 ipa 包并使用 AltStore 等方式侧载安装。
- macOS：到 Release 中下载最新版本的 dmg 包并安装。安装包没有签名，可能需要修改系统设置来安装未签名的包。

## 特别鸣谢

- [pixez-flutter](https://github.com/Notsfsssf/pixez-flutter): 这是本项目的主要参考对象，大量参考了该项目的 API 和 UI 设计。pixez-flutter 是一个非常优秀的项目，遗憾的是在 iOS 设备上的异常发热问题长期未获得解决，这也是本项目诞生的主要动机。
- [Kingfisher](https://github.com/onevcat/Kingfisher): 提供图片加载和缓存
- [TranslationKit](https://github.com/Eslzzyl/TranslationKit): 提供翻译接口，同样是完全的 Vibe Coding 项目
- [GzipSwift](https://github.com/1024jp/GzipSwift): 直连模式手动实现了 HTTP 协议，GzipSwift 为其提供 gzip 解压功能。
- [沉浸式翻译](https://immersivetranslate.com/zh-Hans/): 为项目的翻译功能提供了启发
- [pixivpy](https://github.com/upbit/pixivpy): 提供了 API 参考
- [OpenCode](https://opencode.ai/): OpenCode Zen 计划免费提供的模型实现了本项目的大部分代码
- [MiniMax M2.1](https://www.minimaxi.com/news/minimax-m21): 项目目前的主程序员。
- 其他参与开发的模型：GLM 4.6、GLM 4.7、Gemini 3 flash、Gemini 3 Pro、Grok Code Fast 1

## iOS 截图

<p align="center">
  <img src="./docs/ios_screenshot/推荐.webp" alt="推荐" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/ios_screenshot/动态.webp" alt="动态" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/ios_screenshot/小说.webp" alt="小说" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/ios_screenshot/搜索.webp" alt="搜索" width="200" style="border-radius: 12px; margin: 8px;">
</p>

## macOS 截图

<p align="center">
  <img src="./docs/macos_screenshot/推荐.webp" alt="推荐" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/macos_screenshot/动态.webp" alt="动态" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/macos_screenshot/小说.webp" alt="小说" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/macos_screenshot/搜索.webp" alt="搜索" width="200" style="border-radius: 12px; margin: 8px;">
</p>

---

**免责声明**: 本项目仅供学习研究使用，与 Pixiv 官方无任何关联。

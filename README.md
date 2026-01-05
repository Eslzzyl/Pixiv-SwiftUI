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

- 插画部分该有的应该都有了
- 漫画和小说后续会添加
- 实验性的直连模式：支持绕过 SNI 实现直连。在 Network.framework 的基础上手动实现了 HTTP 协议。
- 翻译：支持自行配置翻译服务来翻译简介、评论等内容

## 系统要求

在设计上，项目同时支持 iOS、iPadOS 和 macOS。项目对 iOS 平台提供最优先支持，对 iPadOS 和 macOS 的支持和优化将在后续补充。

当前的支持情况：
- iOS 26.0 或更新版本：所有功能应当都正常工作。
- iOS 16.0 - iOS 18.0：计划内支持，但目前不支持。
- 更旧的 iOS 版本：不保证能正常使用，也不会提供支持。
- iPadOS 26.0 或更新版本：所有功能应当都正常工作，但预计存在较多布局问题。
- 更旧的 iPadOS 版本：请参考 iOS
- macOS：图片能显示，存在较多布局问题，部分菜单不可用。

## 安装方式

到 Release 中下载最新版本的包并使用 AltStore 等方式侧载安装。

## 特别鸣谢

- [pixez-flutter](https://github.com/Notsfsssf/pixez-flutter): 这是本项目的主要参考对象，大量参考了该项目的 API 和 UI 设计。pixez-flutter 是一个非常优秀的项目，遗憾的是在 iOS 设备上的异常发热问题长期未获得解决，这也是本项目诞生的主要动机。
- [Kingfisher](https://github.com/onevcat/Kingfisher): 提供图片加载和缓存
- [TranslationKit](https://github.com/Eslzzyl/TranslationKit): 提供翻译接口，同样是完全的 Vibe Coding 项目
- [GzipSwift](https://github.com/1024jp/GzipSwift): 直连模式手动实现了 HTTP 协议，GzipSwift 为其提供 gzip 解压功能。
- [沉浸式翻译](https://immersivetranslate.com/zh-Hans/): 为项目的翻译功能提供了启发

## 截图

<p align="center">
  <img src="./docs/screenshots/search.png" alt="搜索" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/screenshots/bookmarks.png" alt="收藏" width="200" style="border-radius: 12px; margin: 8px;">
  <img src="./docs/screenshots/settings.png" alt="设置" width="200" style="border-radius: 12px; margin: 8px;">
</p>

---

**免责声明**: 本项目仅供学习研究使用，与 Pixiv 官方无任何关联。

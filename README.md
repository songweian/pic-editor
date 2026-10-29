# 纸张排版图片编辑器

一套 Flutter 代码覆盖 iOS / Android / Web / macOS / Windows。选纸张、导入图片、缩放裁剪图层，并按纸张尺寸导出 PNG（工作 150 DPI，导出 300 DPI）。

线上 Web：[https://pic.opengear.org](https://pic.opengear.org)

## 运行

需要 Flutter 3.16.x。

```bash
flutter pub get
flutter run -d chrome
flutter run -d macos
```

宽屏为左工具条 + 画布 + 右侧图层/属性；窄屏为顶栏 + 画布 + 底栏，图层在底部抽屉。

## 部署 Web（Cloudflare Workers）

```bash
npm install
npm run deploy
```

会构建 `build/web` 并发布到 Worker `pic-editor`，自定义域名为 `pic.opengear.org`。

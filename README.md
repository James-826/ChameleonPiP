# ChameleonPiP · 变色龙画中画

<p align="center">
  <img src="extension/icons/icon128.png" width="76" height="76" alt="ChameleonPiP Icon" />
</p>

<p align="center">
  无边框桌面融合画中画工具（macOS 原生版 + Chrome / Edge 扩展），完全免费开源。
  <br />
  <a href="https://chameleonpip.site">官网在线试玩</a> ·
  <a href="https://github.com/James-826/ChameleonPiP/releases/latest">直接下载最新版</a> ·
  <a href="https://chameleonpip.site/arena.html">在线计时榜</a>
</p>

<p align="center">
  <img src="docs/preview.png" width="880" alt="ChameleonPiP 变色龙画中画实时桌面融合效果预览" />
</p>

---

## 为什么做这个工具

系统自带的画中画（PiP）会在屏幕上硬盖一块高亮矩形框，写代码、改文档或者对表格的时候非常扎眼，还经常挡住底下的字。

**ChameleonPiP** 去掉了传统画中画的边框，给画面四周做了等宽圆角柔化，并通过 WebGL 着色器把视频的底色抽离掉，让它直接跟着屏幕底下的背景色自适应变化：
- 底下是深色编辑器或终端，小窗就像一层淡淡的光影叠在上面；
- 底下是白底文档或 Excel 表格，画面会自动适配浅色亮度枢轴，底色不被染脏；
- 按一下快捷键还能鼠标穿透，视频放着的同时照常点击、选中和编辑底下的代码。

---

## 主要功能

### 1. 三种桌面融合模式
- **变色融合 (`projector`)**：提取视频的明暗细节叠在当前桌面底色上，红绿对比背景、VS Code 语法高亮和表格文字都能清楚透出来，同时随着底层明暗自动切换亮度枢轴。
- **浮雕隐身 (`emboss`)**：大面积背景区域完全变透明，只用 3D 浮雕线条保留人物和动作轮廓，在办公环境里最隐蔽。
- **彩透变色 (`cinema`)**：保留完整色彩，配合窗口物理像素级四周等宽柔边（`0%–85%`），适合日常追剧或看比赛。

### 2. MacBook 刘海快捷控制 & 桌面小细节
- **刘海控制栏**：`ChameleonPiP.app` 常驻顶部屏幕摄像头刘海两侧，点左耳直接播放/暂停，点右耳展开精简控制面板，不占 Dock 和桌面空间。
- **共享屏幕自动隐身**：支持在腾讯会议、飞书、Zoom 共享屏幕或系统录屏截图时自动隐藏浮窗。
- **鼠标一键穿透 (`⌃⇧M`)**：开启后小窗不再拦截点击和滚轮，需要调节进度条或拖动位置时按住 `Option` 即可临时唤出控制条。
- **触控板双指捏合缩放**：双指直接在小窗上捏合放大或缩小，边框柔化宽度会按窗口当前尺寸实时重新计算。

### 3. 本地防窥自动暂停（可选）
- 开启后通过 macOS 原生 Apple Vision 在内存中统计前置摄像头画面人数；当检测到身后多出第 2 张人脸时，立即静音并隐藏小窗，人走后约 3 秒自动恢复播放。
- 所有识别均在本地内存完成，不拍照、不录像、也不上传任何画面。

### 4. 独立搜片小窗 & 日志伪装字幕
- **内置独立搜片窗口 (`⌃⇧S`)**：不方便在主浏览器翻视频时，按 `⌃⇧S` 呼出独立轻量浏览器直接找片并一键投送进变色龙小窗，自动保留上次搜索关键词和页面进度。
- **代码终端日志字幕**：不方便戴耳机时可开启「日志字幕」，工具会读取网页字幕并配合本地字幕区域识别，把台词转成独立的滚动编译日志窗口。

### 5. 顺手做的计时榜与 1v1 房间
- 内置连续播放时长统计与线上 4 位数字房间号对战，可以和朋友比谁先按老板键暂停（纯娱乐可随时关闭）。

---

## 下载与安装

### 方式一：直接下载安装包（推荐）

前往 [GitHub Releases 最新版](https://github.com/James-826/ChameleonPiP/releases/latest) 或 [官网下载页](https://chameleonpip.site) 下载对应压缩包：

1. **macOS 原生桌面端（`ChameleonPiP-macOS-App-v5.5.zip`）**
   - 解压后将 `ChameleonPiP.app` 拖入「应用程序（`/Applications`）」双击运行。
   - 若首次打开提示来自未识别开发者，可右键点击 `ChameleonPiP.app` 选择「打开」，或在系统设置「隐私与安全性」中点击仍要打开。
2. **Chrome / Edge 浏览器扩展（`ChameleonPiP-Chrome-Extension-v5.5.zip`）**
   - 解压压缩包到本地目录。
   - 打开 `chrome://extensions/`（或 `edge://extensions/`），开启右上角「开发者模式」。
   - 点击「加载已解压的扩展程序」，选中解压出来的文件夹。
   - 打开 B 站、YouTube 等任意视频网页，点击视频右上角的「桌面变色龙小窗」即可直接投送到桌面；更新后记得点一下扩展卡片上的「刷新」。

### 常用全局快捷键

| 快捷键 (macOS) | 作用 |
| :--- | :--- |
| `⌃Control + ⇧Shift + G` | 显示 / 隐藏变色龙小窗（在浏览器中也可作为快速投送触发键） |
| `⌃Control + ⇧Shift + B` | 老板键：一键静音并立刻隐藏小窗，再按恢复 |
| `⌃Control + ⇧Shift + M` | 开关鼠标穿透（开启后可直接操作底层窗口） |
| `⌃Control + ⇧Shift + S` | 显示 / 收起内置独立搜片浏览器 |

### 方式二：从源码编译运行

```bash
git clone https://github.com/James-826/ChameleonPiP.git
cd ChameleonPiP
```

- **编译 macOS 原生客户端（需 Xcode Command Line Tools / `swiftc`）**：
  ```bash
  ./macos-ghost/build.sh
  ```
- **加载浏览器扩展开发版**：在 `chrome://extensions/` 加载仓库下的 `extension/` 目录即可（浏览器端与客户端通过本地 `127.0.0.1:27182` WebSocket 通信）。
- **跨平台 Electron 桌面端（Windows / macOS）**：
  ```bash
  cd desktop
  npm install
  npm start          # 直接运行
  npm run dist:win   # 打包 Windows 安装包
  npm run dist:mac   # 打包 macOS 客户端
  ```
- **可选：自建排位与联机房间服务**：
  ```bash
  node server/arena-server.js
  ```

---

## 项目目录说明

- `macos-ghost/`：macOS 原生版 Swift 源码（`ChameleonPiP.swift`）、WebGL 画中画视图（`ghost-view.html`）与构建脚本（`build.sh`）
- `extension/`：Chrome / Edge Manifest V3 扩展源码（含 Offscreen Capture、Web Worker 帧编码与桥接脚本）
- `desktop/`：跨平台 Electron 桌面端实现
- `web/` 与 `demo/`：产品主页、实时体验交互沙盒与计时榜前端页面
- `server/`：计时榜与 1v1 房间 WebSocket 服务端

---

## English

**ChameleonPiP** is a free, open-source borderless Picture-in-Picture (PiP) player for macOS and Chrome/Edge. Instead of floating an opaque bright rectangle over your workspace, it blends video frames into your underlying IDE, terminal, spreadsheet, or document background with symmetric rounded-edge feathering.

- **Three Blending Modes**:
  - **Projector (`projector`)**: Neutral highlight/shadow luminance mapping that adapts to dark editors or light documents without tinting underlying text.
  - **Emboss (`emboss`)**: 3D contour relief with near-zero flat background fill for minimal distraction.
  - **Cinema (`cinema`)**: Crisp full-color translucency with physical-pixel rounded-rectangle SDF edge feathering.
- **macOS Native Notch Controls (`ChameleonPiP.app`)**: Lives discreetly beside the MacBook notch, hides automatically from screen sharing/capture apps, supports one-key click-through (`Ctrl+Shift+M`) and panic hide (`Ctrl+Shift+B`), and offers optional on-device Apple Vision behind-shoulder peek detection (processed strictly in memory).
- **Quick Start**: Grab the latest macOS app or Chrome extension zip from [Releases](https://github.com/James-826/ChameleonPiP/releases/latest) or try the live WebGL sandbox at [chameleonpip.site](https://chameleonpip.site).

# ChameleonPiP · 变色龙画中画

<p align="center">
  <img src="extension/icons/icon128.png" width="76" height="76" alt="ChameleonPiP Icon" />
</p>

<p align="center">
  无边框桌面融合画中画工具（macOS 原生版 + Chrome / Edge 扩展），基于 MIT 协议开源。
  <br />
  <a href="#为什么做这个工具">简体中文</a> ·
  <a href="#english">English</a> ·
  <a href="https://chameleonpip.site">官网在线试玩</a> ·
  <a href="https://github.com/James-826/ChameleonPiP/releases/latest">直接下载最新版</a>
</p>

<p align="center">
  <img src="docs/preview.png" width="880" alt="ChameleonPiP 变色龙画中画效果预览" />
</p>

---

## 为什么做这个工具

系统自带的画中画（PiP）会在屏幕上硬盖一块高亮矩形框，写代码、改文档或者对表格的时候比较扎眼，还经常挡住底下的文字。

**ChameleonPiP** 去掉了传统画中画的边框，给画面四周做了等宽圆角柔化，再根据底层窗口的明暗色调去叠加画面细节：
- 底下是深色编辑器或终端，小窗会顺着深色底板透出；
- 底下是白底文档或 Excel 表格，画面会自动适配浅色亮度枢轴，尽量不弄脏底色；
- 开启鼠标穿透后，视频放着的同时照常点击、选中和编辑底下的窗口。

---

## 主要功能

### 1. 三种桌面融合模式
- **变色融合 (`projector`)**：提取视频明暗细节叠在当前桌面底色上，底层的代码高亮和表格文字依然可读，会随着底部深浅自动调整对比枢轴。
- **浮雕隐身 (`emboss`)**：大面积平坦背景保持透明，只用立体线条勾勒人物与动作轮廓，适合在工位悄悄开小窗。
- **彩透变色 (`cinema`)**：保留完整原片色彩，配合四周等宽圆角柔边过渡，适合平时正常追剧或看比赛。

### 2. MacBook 刘海控制与常用桌面细节
- **刘海快捷栏**：`ChameleonPiP.app` 停靠在屏幕顶部刘海两侧，点左耳直接播放/暂停，点右耳展开控制栏，不占 Dock 空间。
- **共享屏幕隐藏**：支持在腾讯会议、飞书、Zoom 共享屏幕或系统录屏时自动隐藏小窗。
- **鼠标穿透 (`⌃⇧M`)**：开启后不拦截鼠标点击和滚轮；需要拖动位置或切进度时，按住 `Option` 即可临时唤出控制条。
- **双指缩放**：支持触控板直接双指捏合调整小窗大小，边框柔化宽度也会随之等比例重算。

### 3. 本机背后防窥暂停（可选）
- 开启后只在本机内存中通过 macOS 系统接口统计前置摄像头人数；检测到身后多出第 2 个人影时自动静音隐藏，人走几秒后恢复播放。全程在本地处理，不拍照、不录像、也不上传任何画面。

### 4. 独立搜片小窗与日志样式字幕
- **独立搜片窗口 (`⌃⇧S`)**：不方便开主浏览器时，按 `⌃⇧S` 呼出独立轻量浏览器直接找片并投进小窗，自动记住上次搜过的内容和页面。
- **终端日志字幕**：不方便戴耳机时，可把网页字幕或视频底部字幕实时转成独立的终端日志滚动窗口。

### 5. 计时榜与咖啡支持
- 顺手附带了一个播放时长计时榜，能输 4 位房间号和朋友比谁先按老板键暂停（纯娱乐可忽略）。所有功能完全免费开放；如果这个小工具刚好帮到了你，欢迎点颗 Star 或随心请杯咖啡。

---

## 下载与安装

### 方式一：直接下载安装包（推荐）

前往 [GitHub Releases 最新版](https://github.com/James-826/ChameleonPiP/releases/latest) 或 [官网下载页](https://chameleonpip.site) 下载对应压缩包：

1. **macOS 桌面端（`ChameleonPiP-macOS-App-v5.5.zip`）**
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

- **编译 macOS 客户端（需 Xcode Command Line Tools / `swiftc`）**：
  ```bash
  ./macos-ghost/build.sh
  ```
- **加载浏览器扩展开发版**：在 `chrome://extensions/` 加载仓库下的 `extension/` 目录即可（浏览器端与客户端通过本地 `127.0.0.1:27182` WebSocket 通信）。
- **跨平台 Electron 桌面端（Windows / macOS）**：
  ```bash
  cd desktop
  npm install
  npm start          # 直接运行
  npm run dist:win   # 打包 Windows 安装包/便携版
  npm run dist:mac   # 打包 macOS 客户端
  ```
- **可选：自建计时榜服务**：
  ```bash
  node server/arena-server.js
  ```

---

## 项目目录说明

- `macos-ghost/`：macOS 原生版 Swift 源码（`ChameleonPiP.swift`）、画中画视图（`ghost-view.html`）与构建脚本（`build.sh`）
- `extension/`：Chrome / Edge Manifest V3 扩展源码（负责标签页/网页视频采集并转发至桌面端）
- `desktop/`：跨平台 Electron 桌面端实现
- `web/` 与 `demo/`：产品主页、效果交互沙盒与计时榜前端页面
- `server/`：计时榜与联机房间服务
- [LICENSE](./LICENSE)：MIT 开源协议

---

## English

**ChameleonPiP** is a free, open-source (MIT) borderless Picture-in-Picture (PiP) player for macOS and Chrome/Edge. Instead of slapping an opaque rectangle over your workspace, it blends playback gently into your underlying IDE, terminal, spreadsheet, or document with even rounded-edge feathering.

- **Three Blending Modes**:
  - **Projector (`projector`)**: Blends highlight and shadow details onto the background while keeping underlying syntax highlighting and tables readable.
  - **Emboss (`emboss`)**: Keeps flat areas transparent and leaves only clean 3D contour relief.
  - **Cinema (`cinema`)**: Preserves full colors with soft, uniform edge feathering around all sides.
- **macOS Desktop Details (`ChameleonPiP.app`)**: Docks unobtrusively beside the MacBook notch, automatically hides during screen sharing or recordings, supports click-through (`Ctrl+Shift+M`) and quick boss hide (`Ctrl+Shift+B`), includes a standalone video search popup (`Ctrl+Shift+S`), and optionally detects people walking behind you locally in RAM with zero image storage or uploads.
- **Quick Start**: Grab the latest macOS app or Chrome/Edge extension zip from [Releases](https://github.com/James-826/ChameleonPiP/releases/latest) or try the interactive playground at [chameleonpip.site](https://chameleonpip.site).

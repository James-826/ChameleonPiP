# ChameleonPiP 商店上架提交清单（Chrome Web Store + Microsoft Edge Add-ons）

> 所有文案、权限说明、隐私政策链接与干净商店压缩包均已准备好，直接复制粘贴即可提交审核。

---

## 1. 待上传安装包
- **Chrome / Edge 商店专用压缩包**：`release-bundles/ChameleonPiP-Chrome-Web-Store-v5.2.zip`（已剔除 `.DS_Store` 和开发冗余文件，`manifest_version: 3`，版本 `5.2.0`）
- **图标素材**：`extension/icons/icon128.png`（商店主图标 128×128 PNG）
- **商店截图**：可在官网与排行榜截图（1280×800 PNG，见 `store-submission/`）

---

## 2. 上架后台入口
1. **Microsoft Edge Add-ons（免费，审核最快 1–3 天，强烈建议先上！）**：
   - 控制台：`https://partner.microsoft.com/dashboard/microsoftedge`
2. **Chrome Web Store（一次性注册费 $5，审核约 2–5 天）**：
   - 控制台：`https://chrome.google.com/webstore/devconsole`

---

## 3. 商品信息直接复制模板（中 / 英双语）

### 扩展名称（Extension Name）
- 中文：`ChameleonPiP 变色龙光学画中画`
- 英文：`ChameleonPiP — Optical Transparent Picture-in-Picture`

### 一句话简介（Summary，≤ 132 字符）
- 中文：`60fps 光学透明画中画，底层代码表格与色彩原样透出；支持 Mac 灵动刘海控制、瞬间静音、悬停开关与全球耐力排行榜。`
- 英文：`60fps optical transparent Picture-in-Picture that blends video cleanly over code & spreadsheets with instant tab mute and live rankings.`

### 详细介绍（Detailed Description）
**中文版：**
```
ChameleonPiP（变色龙光学画中画）重新定义网页画中画体验。

【核心特性】
• 60fps 光学透明投影引擎：不再是生硬的半透明黑框，实时将视频转化为纯净光影层，底层代码高亮、Excel 表格与红绿色块原样透出。
• 一键投送与页内悬浮：支持 B站、YouTube、直播及任意 HTML5 视频，按 Ctrl+Shift+G 一键开启桌面端 60fps 无边框投影或页内悬浮。
• 瞬间静音与悬停显形开关：Chrome 标签页级毫秒静音不卡顿；可自由开关「鼠标悬停显形」，关闭后鼠标划过不弹框、按住 Option 随时临时呼出。
• 老板键秒隐：按 Ctrl+Shift+B 一键隐藏画面并自动暂停播放。
• 全球排行榜 & 线上 1v1 耐力 PK：仅在视频真实播放时计时，参与同城 / 国家 / 全球排行与好友 4 位暗号房实时对战。
• 100% 本地渲染隐私保护：视频帧与音频严格停留在您的本机回环通道（127.0.0.1），绝不上传任何网页内容或浏览记录。
```

**English Version:**
```
ChameleonPiP upgrades browser Picture-in-Picture with a real-time 60fps optical projection engine.

KEY FEATURES:
• Optical Transparent Projection: Preserves underlying desktop colors, code syntax highlighting, and spreadsheets instead of covering them with an opaque dark box.
• Instant Casting & In-Page Overlay: Works on YouTube, Bilibili, Twitch, and any HTML5 video. Press Ctrl+Shift+G to cast to the native borderless desktop projector or float in-page.
• Instant Tab-Level Mute & Hover-Reveal Switch: Zero-lag audio mute that works across every site. Toggle Hover-Reveal OFF so passing your mouse over the PiP never pops up distracting borders or HUD bars (hold Option/Alt to peek anytime).
• One-Key Quick Hide: Press Ctrl+Shift+B to hide and pause playback instantaneously.
• Live Global Arena & Endurance PK: Counts strictly during active video playback, with city/global leaderboards and private 4-digit room duels.
• 100% Local Media Privacy: Video frames never leave localhost (127.0.0.1). No browsing history, no screen uploads, no ads.
```

---

## 4. Chrome Web Store「隐私与权限说明（Privacy Practices）」标准填写答案

审核员最看重这部分，直接按以下内容填入即可大幅提升一次过审率：

- **Single Purpose Description（单一用途声明）**：
  > Provides an optical transparent Picture-in-Picture (PiP) video overlay and playback controller for HTML5 videos across web pages, with optional local desktop window casting and playback duration rankings.

- **Permission Justifications（逐项权限理由）**：
  - **`activeTab`**: Needed when the user explicitly clicks the extension icon or hotkey to locate the active `<video>` element on the current page.
  - **`tabCapture`**: Used strictly upon explicit user trigger to capture the current tab's video frames and relay them locally over `127.0.0.1` to the user's local desktop PiP renderer. No media is ever sent to external servers.
  - **`offscreen`**: Hosts the local `OffscreenCanvas` frame cropper and loopback WebSocket relay required by Manifest V3 when tab capture is active.
  - **`scripting`**: Injects the content script on demand if the user opens ChameleonPiP on a tab loaded before extension installation.
  - **`storage`**: Saves user preferences locally (projection mode, intensity, feathering, hover-reveal toggle, and license status).
  - **`tabs`**: Enables instant tab-level mute/unmute synchronization (`chrome.tabs.update`) and cleans up capture cleanly when the source tab closes.
  - **`host_permissions` (`<all_urls>`)**: Allows users to enable optical PiP and detect `<video>` elements on any video website they choose to watch.

- **Privacy Policy URL（隐私政策地址）**：
  - 正式官方地址：`https://chameleonpip.site/privacy.html`

- **Remote Code（是否使用远程代码）**：选 **No, I am not using remote code**（全部 JS 均已打包在扩展内部）。
- **Data Usage Disclosures（数据使用勾选）**：
  - 全部勾选 **No**（不收集 PII、浏览历史、位置定位、财务信息），并在顶部声明仅在用户主动启用可选排行榜或激活码时传输匿名自定义代号与播放时长。

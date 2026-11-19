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
- 中文：`ChameleonPiP 变色龙画中画`
- 英文：`ChameleonPiP — Chameleon Camouflage Picture-in-Picture`

### 一句话简介（Summary，≤ 132 字符）
- 中文：`像变色龙一样融进屏幕的 60fps 零边框画中画，底层代码表格与色彩原样透出；支持 Mac 灵动刘海、鼠标穿透、瞬间静音与全球耐力榜。`
- 英文：`60fps chameleon Picture-in-Picture that blends video cleanly over code & spreadsheets with click-through, instant tab mute and live rankings.`

### 详细介绍（Detailed Description）
**中文版：**
```
ChameleonPiP（变色龙画中画）—— 像变色龙一样融进你的屏幕！

【核心特性】
• 60fps 变色龙拟态融合引擎：告别生硬的半透明黑框，底层代码高亮、Excel 表格与红绿色块原样透出，与桌面自然融为一体。
• 一键投送与页内悬浮：支持 B站、YouTube、直播及任意 HTML5 视频，按 Ctrl+Shift+G 一键开启桌面端 60fps 无边框变色小窗或页内悬浮。
• 鼠标穿透 + 悬停显形开关：点击小窗箭头按钮或按 Ctrl+Shift+M 即可开启鼠标穿透，隔着视频直接操作底下文档和代码；默认关闭悬停显形，鼠标划过不弹框、按住 Option 随时临时呼出。
• 标签页级瞬间静音 & 老板键：毫秒级响应不卡顿，按 Ctrl+Shift+B 一键秒隐并自动暂停播放。
• 全球变色龙排行榜 & 线上 1v1 耐力 PK：仅在视频真实播放时计时，参与同城 / 国家 / 全球排行与好友 4 位暗号房实时对战。
• 100% 本地渲染隐私保护：视频帧与音频严格停留在您的本机回环通道（127.0.0.1），绝不上传任何网页内容或浏览记录。
```

**English Version:**
```
ChameleonPiP blends Picture-in-Picture video into your desktop like a real chameleon.

KEY FEATURES:
• 60fps Chameleon Camouflage: Preserves underlying desktop colors, code syntax highlighting, and spreadsheets instead of covering them with an opaque dark box.
• Instant Casting & In-Page Overlay: Works on YouTube, Bilibili, Twitch, and any HTML5 video. Press Ctrl+Shift+G to cast to the native borderless desktop window or float in-page.
• Instant Click-Through & Hover-Reveal Switch: Click the window arrow or press Ctrl+Shift+M to click right through the video onto your apps underneath. Hover-Reveal is OFF by default so passing your mouse over the window never pops up distracting HUD bars (hold Option/Alt to peek anytime).
• Instant Tab-Level Mute & Quick Hide: Zero-lag audio mute across every site; press Ctrl+Shift+B to hide and pause instantaneously.
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

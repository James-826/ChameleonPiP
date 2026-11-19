# ChameleonPiP 变色龙画中画 (v5.2)

<p align="center">
  <img src="extension/icons/icon128.png" width="96" height="96" alt="ChameleonPiP Icon" />
</p>

**ChameleonPiP（变色龙画中画）** 是一款像变色龙一样融进桌面的**零边框拟态视频画中画工具**。它不再往屏幕上盖一层突兀的视频方框，而是随环境底色自然融合——**底层桌面是什么颜色（如红绿撞色、VS Code 深色代码、飞书白底文档或 Excel 表格），小窗内部就 100% 原封不动透出底色**，而实时播放的视频画面与字幕则自然呈现在其上。

同时内置 **全球摸鱼排位榜（同城 / 国家 / 全球）**、**十阶段位勋章体系** 与 **线上不间断耐力 1v1 对战（PK）**。

---

## 在线体验与全球实时排位

- **官方产品主页与变色龙实时体验**：[https://chameleonpip.site](https://chameleonpip.site)
- **全球潜伏排位与 1v1 耐力对战竞技场**：[https://chameleonpip.site/arena.html](https://chameleonpip.site/arena.html)
- **隐私政策（Privacy Policy）**：[https://chameleonpip.site/privacy.html](https://chameleonpip.site/privacy.html)

---

## 核心特性

### 1. 60fps Apple Metal WebGL 变色龙拟态引擎
- **变色融合 (`projector`)**：像变色龙一样融入底层任意颜色/代码/表格，底色原样透出不发灰，细腻保留人物动作与字幕。
- **浮雕隐身 (`emboss` · Pro)**：提取视频凹凸轮廓浅雕在桌面材质上，平坦区域完全透明。
- **彩透变色 (`cinema` · Pro)**：保留轻度原片色彩并与桌面背景柔和融合。

### 2. MacBook 摄像头灵动刘海（Dynamic Island）& Windows 系统托盘
- **macOS 原生版（`GeckoGhost.app`）**：无缝融入屏幕正上方物理摄像头刘海——点击左耳直接实时播放/暂停，点击右耳展开原生精简灵动岛（实时进度条拖拽、倍速、浓度、鼠标穿透、连续潜伏计时与一键呼出排行/对战）。
- **小窗全功能直控**：鼠标移入小窗浮现毛玻璃控制条，支持按住小窗四边/四角八向自由拖拽调整尺寸，支持防截屏保护与全局快捷键（`⌃⇧G` 显隐、`⌃⇧B` 老板键秒隐、`⌃⇧M` 鼠标穿透）。

### 3. 全球摸鱼排行榜、十阶矢量勋章 & 线上不间断耐力 PK
- **自动潜伏记录**：播放视频时自动累计连续不间断时长、今日总时长与带薪折算收益；暂停超过 10 秒或触发老板键 `⌃⇧B` 自动结算本轮纪录。
- **同城 / 国家 / 全球三维排行榜**：支持按同城、国家/地区热度、全球查看「不间断纪录 / 今日累计 / PK 积分」排名，配备手绘级矢量 SVG 冠亚季军六边形奖牌、矢量国旗与十阶几何段位徽章（`Lv.1 透明实习生` ～ `Lv.10 摸鱼之神`）。
- **实时 WebSocket 1v1 耐力对战**：支持全球随机匹配或输入 4 位数字房间号与同事同房开局，每秒实时同步双方读秒，谁先暂停视频或触发老板键谁即判负并结算 ELO 积分。

---

## 快速开始

### 1. Chrome / Edge 浏览器扩展
1. 克隆本仓库：`git clone https://github.com/James-826/ChameleonPiP.git`
2. 打开浏览器进入 `chrome://extensions/`（或 `edge://extensions/`），开启右上角「开发者模式」。
3. 点击「加载已解压的扩展程序」，选择仓库中的 [`extension`](./extension) 文件夹。
4. 打开任意视频网页（B站、YouTube、抖音等），按 **`Ctrl + Shift + G`**（Mac 为 **`⌃Control + ⇧Shift + G`**）即可开启变色龙画中画。

### 2. macOS 原生灵动刘海桌面版
- 直接双击运行仓库根目录下的 [`GeckoGhost.app`](./GeckoGhost.app)（或执行 `./macos-ghost/build.sh` 从 Swift 源码重新编译）。

### 3. Windows / macOS 跨平台桌面版（Electron）
```bash
cd desktop
npm install
npm start          # 直接运行
npm run dist:win   # 打包 Windows 安装包/便携版
npm run dist:mac   # 打包 macOS 客户端
```

### 4. 自建全球排位与 PK 服务端（可选，默认已连接官方 Cloudflare 加密隧道节点）
客户端已默认连接官方 Cloudflare 加密节点，开箱即可与全球用户同榜排行与实时 PK。如需自建私有节点：
```bash
node server/arena-server.js
# 默认监听 127.0.0.1:51938，可在排位页顶部点击「实时联机服」徽章切换自定义服务器地址
```

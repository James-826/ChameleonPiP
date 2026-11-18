"use strict";

const {
  app,
  BrowserWindow,
  Tray,
  Menu,
  screen,
  globalShortcut,
  ipcMain,
  dialog,
  desktopCapturer,
  nativeImage,
} = require("electron");
const http = require("http");
const crypto = require("crypto");
const path = require("path");
const { pathToFileURL } = require("url");

let ghostWin = null;
let menuWin = null;
let tray = null;

const uiState = {
  visible: true,
  bossMode: false,
  clickThrough: false,
  captureHide: true,
  autoSense: true,
  mode: "projector",
  stealth: 58,
  feather: 28,
};

// ---------------------------------------------------------------------------
// 1. Zero-Dependency RFC-6455 WebSocket Hub (127.0.0.1:51937) for Chrome/Edge
// ---------------------------------------------------------------------------
function startLocalWebSocketHub(port = 51937) {
  const clients = new Set();

  function encodeWsFrame(opcode, payloadBuf) {
    const len = payloadBuf.length;
    let header;
    if (len < 126) {
      header = Buffer.alloc(2);
      header[0] = 0x80 | opcode;
      header[1] = len;
    } else if (len < 65536) {
      header = Buffer.alloc(4);
      header[0] = 0x80 | opcode;
      header[1] = 126;
      header.writeUInt16BE(len, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode;
      header[1] = 127;
      header.writeBigUInt64BE(BigInt(len), 2);
    }
    return Buffer.concat([header, payloadBuf]);
  }

  const server = http.createServer((_req, res) => {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ app: "GeckoPiP", ok: true }));
  });

  server.on("upgrade", (req, socket) => {
    socket.setNoDelay(true);
    const key = req.headers["sec-websocket-key"];
    if (!key) {
      socket.destroy();
      return;
    }
    const accept = crypto
      .createHash("sha1")
      .update(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
      .digest("base64");

    socket.write(
      [
        "HTTP/1.1 101 Switching Protocols",
        "Upgrade: websocket",
        "Connection: Upgrade",
        `Sec-WebSocket-Accept: ${accept}`,
        "\r\n",
      ].join("\r\n")
    );

    const client = { socket, isGhostView: false, buf: Buffer.alloc(0) };
    clients.add(client);

    socket.on("data", (chunk) => {
      client.buf = Buffer.concat([client.buf, chunk]);
      while (client.buf.length >= 2) {
        const b0 = client.buf[0];
        const b1 = client.buf[1];
        const opcode = b0 & 0x0f;
        const masked = (b1 & 0x80) !== 0;
        let payloadLen = b1 & 0x7f;
        let offset = 2;

        if (payloadLen === 126) {
          if (client.buf.length < 4) return;
          payloadLen = client.buf.readUInt16BE(2);
          offset = 4;
        } else if (payloadLen === 127) {
          if (client.buf.length < 10) return;
          payloadLen = Number(client.buf.readBigUInt64BE(2));
          offset = 10;
        }

        const maskBytes = masked ? 4 : 0;
        if (client.buf.length < offset + maskBytes + payloadLen) return;

        let payload = client.buf.subarray(offset + maskBytes, offset + maskBytes + payloadLen);
        if (masked) {
          const mask = client.buf.subarray(offset, offset + 4);
          const unmasked = Buffer.allocUnsafe(payload.length);
          for (let i = 0; i < payload.length; i++) {
            unmasked[i] = payload[i] ^ mask[i & 3];
          }
          payload = unmasked;
        }
        client.buf = client.buf.subarray(offset + maskBytes + payloadLen);

        if (opcode === 0x08) {
          socket.end();
          clients.delete(client);
          return;
        }
        if (opcode === 0x09) {
          socket.write(encodeWsFrame(0x0a, payload));
          continue;
        }

        if (opcode === 0x01) {
          const text = payload.toString("utf8");
          if (text.includes('"role":"ghostView"')) {
            client.isGhostView = true;
          } else if (client.isGhostView) {
            const out = encodeWsFrame(0x01, payload);
            for (const c of clients) {
              if (c !== client && !c.isGhostView) c.socket.write(out);
            }
          } else {
            const out = encodeWsFrame(0x01, payload);
            for (const c of clients) {
              if (c !== client && c.isGhostView) c.socket.write(out);
            }
          }
        } else if (opcode === 0x02) {
          const out = encodeWsFrame(0x02, payload);
          for (const c of clients) {
            if (c !== client && c.isGhostView) c.socket.write(out);
          }
        }
      }
    });

    socket.on("close", () => clients.delete(client));
    socket.on("error", () => clients.delete(client));
  });

  server.listen(port, "127.0.0.1");
}

// ---------------------------------------------------------------------------
// 2. Borderless Resizable Transparent PiP Window (macOS + Windows)
// ---------------------------------------------------------------------------
function createGhostWindow() {
  const workArea = screen.getPrimaryDisplay().workArea;
  const w = 384;
  const h = 216;

  ghostWin = new BrowserWindow({
    x: workArea.x + workArea.width - w - 24,
    y: workArea.y + workArea.height - h - 24,
    width: w,
    height: h,
    minWidth: 190,
    minHeight: 110,
    frame: false,
    transparent: true,
    hasShadow: false,
    resizable: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  ghostWin.setAlwaysOnTop(true, "floating");
  ghostWin.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  ghostWin.setContentProtection(uiState.captureHide);

  const viewPath = path.join(__dirname, "ghost-view.html");
  ghostWin.loadFile(viewPath);
}

// ---------------------------------------------------------------------------
// 3. macOS Top Menu Bar / Windows System Tray Popover Panel
// ---------------------------------------------------------------------------
function createMenuPopoverWindow() {
  const isMac = process.platform === "darwin";
  menuWin = new BrowserWindow({
    width: 296,
    height: 482,
    show: false,
    frame: false,
    transparent: isMac,
    vibrancy: isMac ? "popover" : undefined,
    visualEffectState: isMac ? "active" : undefined,
    resizable: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    backgroundColor: isMac ? "#00000000" : "#161920",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  menuWin.loadFile(path.join(__dirname, "menubar.html"));
  menuWin.on("blur", () => {
    menuWin?.hide();
  });
}

function toggleMenuPopover() {
  if (!menuWin) return;
  if (menuWin.isVisible()) {
    menuWin.hide();
    return;
  }

  const trayBounds = tray.getBounds();
  const winBounds = menuWin.getBounds();
  const disp = screen.getDisplayNearestPoint({ x: trayBounds.x, y: trayBounds.y });
  const area = disp.workArea;

  let x = Math.round(trayBounds.x + trayBounds.width / 2 - winBounds.width / 2);
  let y;
  if (process.platform === "darwin") {
    // Anchor directly below the macOS Top Menu Bar icon!
    y = Math.round(trayBounds.y + trayBounds.height + 4);
  } else {
    // Anchor neatly above/near the Windows System Tray icon!
    y =
      trayBounds.y > disp.bounds.height / 2
        ? Math.round(trayBounds.y - winBounds.height - 6)
        : Math.round(trayBounds.y + trayBounds.height + 6);
  }

  x = Math.max(area.x + 6, Math.min(x, area.x + area.width - winBounds.width - 6));
  y = Math.max(area.y + 4, Math.min(y, area.y + area.height - winBounds.height - 4));

  menuWin.setPosition(x, y, false);
  menuWin.webContents.executeJavaScript(
    `window.GeckoMenuBridge?.sync(${JSON.stringify(uiState)});`
  ).catch(() => {});
  menuWin.show();
  menuWin.focus();
}

function setupTray() {
  let img;
  if (process.platform === "darwin") {
    const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18">
      <rect x="2" y="3.5" width="14" height="11" rx="2.8" fill="none" stroke="#000" stroke-width="1.5"/>
      <circle cx="9" cy="9" r="2.3" fill="#000"/>
      <line x1="5.2" y1="6.3" x2="6.7" y2="7.4" stroke="#000" stroke-width="1.2" stroke-linecap="round"/>
      <line x1="12.8" y1="11.7" x2="11.3" y2="10.6" stroke="#000" stroke-width="1.2" stroke-linecap="round"/>
    </svg>`;
    img = nativeImage.createFromDataURL(`data:image/svg+xml;base64,${Buffer.from(svg).toString("base64")}`);
    img.setTemplateImage(true);
  } else {
    const iconPath = path.join(__dirname, "icons", "icon32.png");
    img = nativeImage.createFromPath(iconPath).resize({ width: 18, height: 18 });
  }
  tray = new Tray(img);
  tray.setToolTip("GeckoPiP 光学投影画中画");

  tray.on("click", () => toggleMenuPopover());
  tray.on("right-click", () => {
    const contextMenu = Menu.buildFromTemplate([
      { label: "打开控制面板", click: () => toggleMenuPopover() },
      {
        label: uiState.visible ? "隐藏小窗 (Ctrl+Shift+G)" : "显示小窗 (Ctrl+Shift+G)",
        click: () => applyHostAction({ action: "setVisible", value: !uiState.visible }),
      },
      {
        label: uiState.clickThrough ? "关闭鼠标穿透 (Ctrl+Shift+M)" : "开启鼠标穿透 (Ctrl+Shift+M)",
        click: () => applyHostAction({ action: "setClickThrough", value: !uiState.clickThrough }),
      },
      { type: "separator" },
      { label: "退出 GeckoPiP", click: () => app.quit() },
    ]);
    tray.popUpContextMenu(contextMenu);
  });
}

// ---------------------------------------------------------------------------
// 4. Cross-Platform Screen Color Auto-Sampling (macOS & Windows)
// ---------------------------------------------------------------------------
function startCrossPlatformScreenSampler() {
  setInterval(async () => {
    if (!ghostWin || !uiState.visible || uiState.bossMode || !uiState.autoSense) return;
    try {
      const sources = await desktopCapturer.getSources({
        types: ["screen"],
        thumbnailSize: { width: 96, height: 54 },
      });
      const thumb = sources[0]?.thumbnail;
      if (!thumb || thumb.isEmpty()) return;

      const disp = screen.getPrimaryDisplay().bounds;
      const wb = ghostWin.getBounds();
      const size = thumb.getSize();
      const bitmap = thumb.toBitmap(); // BGRA on Windows/macOS

      // Sample thin perimeter ring just outside the window bounds so we read the surrounding page!
      const nx = Math.max(0, Math.min(size.width - 1, Math.round(((wb.x - disp.x - 6) / disp.width) * size.width)));
      const ny = Math.max(0, Math.min(size.height - 1, Math.round(((wb.y - disp.y - 6) / disp.height) * size.height)));
      const idx = (ny * size.width + nx) * 4;
      const b = bitmap[idx];
      const g = bitmap[idx + 1];
      const r = bitmap[idx + 2];
      const hex = `#${[r, g, b].map((v) => v.toString(16).padStart(2, "0")).join("")}`;

      ghostWin.webContents.executeJavaScript(
        `window.GeckoNativeBridge?.onMacSensor({bgColor:'${hex}',archetype:'web',isTyping:false});`
      ).catch(() => {});
    } catch (_) {}
  }, 900);
}

// ---------------------------------------------------------------------------
// 5. Unified Action Router & Global Shortcuts (Mac + Windows)
// ---------------------------------------------------------------------------
let pointerTimer = null;

function stopPointerTrack() {
  if (pointerTimer) {
    clearInterval(pointerTimer);
    pointerTimer = null;
  }
}

function startPointerTrack(kind, dir = "se") {
  stopPointerTrack();
  if (!ghostWin) return;
  const startPt = screen.getCursorScreenPoint();
  const startBounds = ghostWin.getBounds();
  const minW = 190;
  const minH = 110;

  pointerTimer = setInterval(() => {
    if (!ghostWin || ghostWin.isDestroyed()) {
      stopPointerTrack();
      return;
    }
    const cur = screen.getCursorScreenPoint();
    const dx = cur.x - startPt.x;
    const dy = cur.y - startPt.y;
    if (dx === 0 && dy === 0) return;

    if (kind === "drag") {
      ghostWin.setPosition(startBounds.x + dx, startBounds.y + dy, false);
      return;
    }

    let x = startBounds.x;
    let y = startBounds.y;
    let w = startBounds.width;
    let h = startBounds.height;

    if (dir.includes("e")) w = Math.max(minW, startBounds.width + dx);
    if (dir.includes("s")) h = Math.max(minH, startBounds.height + dy);
    if (dir.includes("w")) {
      const nw = Math.max(minW, startBounds.width - dx);
      x = startBounds.x + (startBounds.width - nw);
      w = nw;
    }
    if (dir.includes("n")) {
      const nh = Math.max(minH, startBounds.height - dy);
      y = startBounds.y + (startBounds.height - nh);
      h = nh;
    }
    ghostWin.setBounds({ x: Math.round(x), y: Math.round(y), width: Math.round(w), height: Math.round(h) }, false);
  }, 16);
}

async function applyHostAction(msg) {
  if (!msg || !ghostWin) return;

  switch (msg.action) {
    case "beginDrag":
      startPointerTrack("drag");
      return;

    case "beginResize":
      startPointerTrack("resize", String(msg.dir || "se"));
      return;

    case "endPointerTrack":
      stopPointerTrack();
      return;
    case "setVisible":
      uiState.visible = Boolean(msg.value);
      if (uiState.visible) ghostWin.showInactive();
      else ghostWin.hide();
      break;

    case "setBoss":
      uiState.bossMode = Boolean(msg.value);
      ghostWin.webContents.executeJavaScript(
        `window.GeckoNativeBridge?.setBossMode(${uiState.bossMode});`
      ).catch(() => {});
      break;

    case "enableClickThrough":
    case "setClickThrough":
      uiState.clickThrough = msg.action === "enableClickThrough" ? true : Boolean(msg.value);
      ghostWin.setIgnoreMouseEvents(uiState.clickThrough, { forward: true });
      break;

    case "setCaptureHide":
      uiState.captureHide = Boolean(msg.value);
      ghostWin.setContentProtection(uiState.captureHide);
      break;

    case "patchState":
      if (msg.patch) {
        Object.assign(uiState, msg.patch);
        ghostWin.webContents.executeJavaScript(
          `window.GeckoNativeBridge?.applyPatch(${JSON.stringify(msg.patch)});`
        ).catch(() => {});
      }
      break;

    case "stateChanged":
      if (msg.state) {
        Object.assign(uiState, {
          mode: msg.state.mode,
          stealth: msg.state.stealth,
          opacity: msg.state.opacity,
          feather: msg.state.feather,
        });
      }
      break;

    case "playerChanged":
      if (msg.player && menuWin?.isVisible()) {
        menuWin.webContents.executeJavaScript(
          `window.GeckoMenuBridge?.syncPlayer(${JSON.stringify(msg.player)});`
        ).catch(() => {});
      }
      return;

    case "resizeWindow":
      if (msg.width && msg.height) {
        ghostWin.setSize(Math.round(msg.width), Math.round(msg.height), true);
      }
      break;

    case "snapCorner": {
      const area = screen.getDisplayMatching(ghostWin.getBounds()).workArea;
      const b = ghostWin.getBounds();
      const pad = 22;
      const pos = {
        tl: [area.x + pad, area.y + pad],
        tr: [area.x + area.width - b.width - pad, area.y + pad],
        bl: [area.x + pad, area.y + area.height - b.height - pad],
        br: [area.x + area.width - b.width - pad, area.y + area.height - b.height - pad],
      }[msg.corner || "br"];
      if (pos) ghostWin.setPosition(pos[0], pos[1], true);
      break;
    }

    case "playerCmd":
      if (msg.cmd) {
        ghostWin.webContents.executeJavaScript(
          `window.GeckoNativeBridge?.execPlayerCmd(${JSON.stringify(msg.cmd)});`
        ).catch(() => {});
      }
      break;

    case "openLocalMp4": {
      const res = await dialog.showOpenDialog({
        properties: ["openFile"],
        filters: [{ name: "Videos", extensions: ["mp4", "webm", "mov", "mkv"] }],
      });
      if (!res.canceled && res.filePaths[0]) {
        const fileUrl = pathToFileURL(res.filePaths[0]).href;
        ghostWin.webContents.executeJavaScript(
          `window.GeckoNativeBridge?.loadLocalVideo(${JSON.stringify(fileUrl)});`
        ).catch(() => {});
      }
      break;
    }

    case "quitApp":
      app.quit();
      break;
  }

  if (menuWin?.isVisible()) {
    menuWin.webContents.executeJavaScript(
      `window.GeckoMenuBridge?.sync(${JSON.stringify(uiState)});`
    ).catch(() => {});
  }
}

ipcMain.on("gecko-action", (_ev, payload) => {
  applyHostAction(payload);
});

app.whenReady().then(() => {
  if (process.platform === "darwin" && app.dock) {
    app.dock.hide();
  }

  startLocalWebSocketHub(51937);
  createGhostWindow();
  createMenuPopoverWindow();
  setupTray();
  startCrossPlatformScreenSampler();

  // Register Global Shortcuts working identically on macOS (⌃⇧G/B/M) & Windows (Ctrl+Shift+G/B/M)!
  globalShortcut.register("Control+Shift+G", () => {
    applyHostAction({ action: "setVisible", value: !uiState.visible });
  });
  globalShortcut.register("Control+Shift+B", () => {
    applyHostAction({ action: "setBoss", value: !uiState.bossMode });
  });
  globalShortcut.register("Control+Shift+M", () => {
    applyHostAction({ action: "setClickThrough", value: !uiState.clickThrough });
  });
});

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
});

"use strict";

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("GeckoDesktopBridge", {
  send(payload) {
    ipcRenderer.send("gecko-action", payload);
  },
});

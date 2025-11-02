"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const electron_1 = require("electron");
const electronAPI = {
    // GitHub PR Reviews
    getPrReviews: (owner, repo) => electron_1.ipcRenderer.invoke('github:getPrReviews', owner, repo),
    // App control
    onTrayClick: (callback) => {
        electron_1.ipcRenderer.on('tray:click', callback);
        return () => electron_1.ipcRenderer.removeListener('tray:click', callback);
    },
};
electron_1.contextBridge.exposeInMainWorld('electronAPI', electronAPI);

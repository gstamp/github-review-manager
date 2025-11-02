import { contextBridge, ipcRenderer } from 'electron';

const electronAPI = {
  // GitHub PR Reviews
  getPrReviews: (owner: string, repo: string) =>
    ipcRenderer.invoke('github:getPrReviews', owner, repo),

  // GitHub User PRs
  getUserOpenPrs: (forceRefresh?: boolean) =>
    ipcRenderer.invoke('github:getUserOpenPrs', forceRefresh),

  // GitHub Review Requests
  getReviewRequests: (forceRefresh?: boolean) =>
    ipcRenderer.invoke('github:getReviewRequests', forceRefresh),

  // Dismiss PR
  dismissPr: (prId: number) => ipcRenderer.invoke('github:dismissPr', prId),

  // App control
  onTrayClick: (callback: () => void) => {
    ipcRenderer.on('tray:click', callback);
    return () => ipcRenderer.removeListener('tray:click', callback);
  },
  quit: () => ipcRenderer.invoke('app:quit'),
};

contextBridge.exposeInMainWorld('electronAPI', electronAPI);

export type ElectronAPI = typeof electronAPI;


import { app, BrowserWindow, shell } from 'electron';
import { join } from 'path';
import { createTray } from './tray';
import { registerIpcHandlers } from './ipc';

let mainWindow: BrowserWindow | null = null;
let trayWindow: BrowserWindow | null = null;

const isDev = process.env.NODE_ENV === 'development' || !app.isPackaged;

function getPreloadPath(): string {
  return join(__dirname, '../preload/index.js');
}

function setupExternalLinks(window: BrowserWindow): void {
  // Open external links in default browser and focus it
  window.webContents.setWindowOpenHandler(({ url }) => {
    shell.openExternal(url, { activate: true });
    return { action: 'deny' };
  });

  // Prevent navigation to external URLs within Electron
  window.webContents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    const isDevUrl = isDev && parsedUrl.hostname === 'localhost' && parsedUrl.port === '5173';
    const isLocalFile = navigationUrl.startsWith('file://');

    if (!isDevUrl && !isLocalFile) {
      event.preventDefault();
      shell.openExternal(navigationUrl, { activate: true });
    }
  });
}

function createMainWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 1024,
    height: 768,
    show: false,
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  setupExternalLinks(window);

  if (isDev) {
    window.loadURL('http://localhost:5173');
    window.webContents.openDevTools();
  } else {
    window.loadFile(join(__dirname, '../renderer/index.html'));
  }

  return window;
}

function createTrayWindow(): BrowserWindow {
  const window = new BrowserWindow({
    width: 800,
    height: 600,
    show: false,
    frame: false,
    resizable: false,
    skipTaskbar: true,
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  setupExternalLinks(window);

  if (isDev) {
    window.loadURL('http://localhost:5173');
  } else {
    window.loadFile(join(__dirname, '../renderer/index.html'));
  }

  return window;
}

function setupTrayWindowBlur(window: BrowserWindow): void {
  // Close window on blur to prevent tiling window manager workspace switching
  window.on('blur', () => {
    window.close();
  });
}

app.whenReady().then(() => {
  mainWindow = createMainWindow();
  trayWindow = createTrayWindow();
  setupTrayWindowBlur(trayWindow);

  createTray(trayWindow, createTrayWindow, setupExternalLinks);

  registerIpcHandlers();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      mainWindow = createMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

app.on('before-quit', () => {
  if (trayWindow) {
    trayWindow.removeAllListeners('close');
    trayWindow.close();
  }
});

export { mainWindow, trayWindow };


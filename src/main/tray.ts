import { Tray, Menu, nativeImage, BrowserWindow, screen, shell } from 'electron';
import { join } from 'path';

let tray: Tray | null = null;
let trayWindow: BrowserWindow | null = null;
let createTrayWindowFn: (() => BrowserWindow) | null = null;
let setupExternalLinksFn: ((window: BrowserWindow) => void) | null = null;

export function createTray(window: BrowserWindow, createWindowFn: () => BrowserWindow, setupLinksFn: (window: BrowserWindow) => void): void {
  trayWindow = window;
  createTrayWindowFn = createWindowFn;
  setupExternalLinksFn = setupLinksFn;
  // Try to load icon from assets, fallback to programmatically created icon if not found
  const iconPath = join(__dirname, '../../assets/icon.png');
  let icon = nativeImage.createFromPath(iconPath);

  // Fallback to a simple programmatically created icon if file doesn't exist
  if (icon.isEmpty()) {
    // Create a simple 16x16 icon with a "G" for GitHub
    icon = createDefaultTrayIcon();
  } else {
    // Set as template image for macOS (allows system to style it for light/dark mode)
    icon.setTemplateImage(true);
  }

  tray = new Tray(icon);

  // Ensure tray is visible
  if (!tray) {
    console.error('Failed to create tray icon');
    return;
  }

  console.log('Tray icon created successfully');

  tray.setToolTip('GitHub Review Manager');

  // Handle left click to toggle window
  tray.on('click', () => {
    toggleTrayWindow();
  });

  // Handle right click for context menu (optional - includes Quit option)
  tray.on('right-click', () => {
    const contextMenu = Menu.buildFromTemplate([
      {
        label: 'Quit',
        click: () => {
          BrowserWindow.getAllWindows().forEach((window) => window.close());
        },
      },
    ]);
    tray?.popUpContextMenu(contextMenu);
  });
}

function toggleTrayWindow(): void {
  // Recreate window if it was destroyed
  if (!trayWindow || trayWindow.isDestroyed()) {
    if (!createTrayWindowFn || !setupExternalLinksFn) return;
    trayWindow = createTrayWindowFn();
    setupTrayWindow(trayWindow, setupExternalLinksFn);
  }

  if (trayWindow.isVisible()) {
    trayWindow.close();
  } else {
    const position = getTrayWindowPosition(trayWindow);
    trayWindow.setPosition(position.x, position.y, false);
    trayWindow.show();
    trayWindow.focus();
  }
}

function setupTrayWindow(window: BrowserWindow, setupExternalLinks: (window: BrowserWindow) => void): void {
  // Setup blur handler to close window (prevents workspace switching in tiling WMs)
  window.on('blur', () => {
    window.close();
  });

  // Setup external links for recreated window
  setupExternalLinks(window);
}

function getTrayWindowPosition(trayWindow: BrowserWindow): { x: number; y: number } {
  const windowBounds = trayWindow.getBounds();
  const trayBounds = tray?.getBounds();

  if (!trayBounds) {
    const display = screen.getPrimaryDisplay();
    const { width } = display.workAreaSize;
    return {
      x: width - windowBounds.width - 10,
      y: 10,
    };
  }

  const x = Math.round(trayBounds.x + trayBounds.width / 2 - windowBounds.width / 2);
  const y = Math.round(trayBounds.y + trayBounds.height);

  return { x, y };
}

function createDefaultTrayIcon(): Electron.NativeImage {
  // Create a simple 16x16 icon for macOS tray
  // macOS tray icons should be template images (black on transparent)
  const size = 16;
  const scale = 2; // Use @2x for retina displays
  const actualSize = size * scale;

  // Create RGBA buffer for the icon
  const buffer = Buffer.alloc(actualSize * actualSize * 4);

  // Draw a simple filled circle/square shape (visible icon)
  const centerX = actualSize / 2;
  const centerY = actualSize / 2;
  const radius = actualSize / 2 - 2;

  for (let y = 0; y < actualSize; y++) {
    for (let x = 0; x < actualSize; x++) {
      const dx = x - centerX;
      const dy = y - centerY;
      const distance = Math.sqrt(dx * dx + dy * dy);

      const index = (y * actualSize + x) * 4;

      if (distance <= radius) {
        // White/light color for visibility (macOS will adapt it)
        buffer[index] = 50;     // R
        buffer[index + 1] = 50;  // G
        buffer[index + 2] = 50;  // B
        buffer[index + 3] = 255; // A (opaque)
      } else {
        // Transparent
        buffer[index] = 0;
        buffer[index + 1] = 0;
        buffer[index + 2] = 0;
        buffer[index + 3] = 0;
      }
    }
  }

  const image = nativeImage.createFromBuffer(buffer, {
    width: actualSize,
    height: actualSize,
    scaleFactor: scale,
  });

  // Set as template image for macOS (allows system to style it)
  image.setTemplateImage(true);

  return image;
}


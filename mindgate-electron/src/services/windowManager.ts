import { BrowserWindow, screen } from 'electron';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { Configuration, ActiveWindowInfo } from '../types.js';
import { SystemMonitor } from './platformWrapper.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

export class WindowManager {
  private overlayWindow: BrowserWindow | null = null;
  private configuration: Configuration;
  private targetApp: ActiveWindowInfo | null = null;

  constructor(configuration: Configuration) {
    this.configuration = configuration;
  }

  setOverlayWindow(window: BrowserWindow) {
    this.overlayWindow = window;
  }

  setTargetWindow(window: ActiveWindowInfo | null) {
    this.targetApp = window;
  }

  getTargetApp(): ActiveWindowInfo | null {
    return this.targetApp;
  }

  createOverlayWindow(): BrowserWindow {
    const primaryDisplay = screen.getPrimaryDisplay();
    const { bounds } = primaryDisplay;

    this.overlayWindow = new BrowserWindow({
      x: Math.round(bounds.x + this.configuration.theme.dimensions.overlayXOffset),
      y: Math.round(bounds.y + this.configuration.theme.dimensions.overlayYOffset),
      width: this.configuration.theme.dimensions.overlayWidth,
      height: this.configuration.theme.dimensions.overlayHeight,
      transparent: true,
      frame: false,
      alwaysOnTop: true,
      skipTaskbar: true,
      resizable: false,
      movable: false,
      hasShadow: false,
      focusable: true,
      acceptFirstMouse: true,
      minimizable: false,
      maximizable: false,
      webPreferences: {
        preload: join(__dirname, '../preload.js'),
        contextIsolation: true,
        nodeIntegration: false
      }
    });

    return this.overlayWindow;
  }

  showOverlay(targetWindow?: ActiveWindowInfo) {
    const window = targetWindow ?? this.targetApp;
    
    if (window && window.frame && window.frame.width > 0) {
      this.overlayWindow?.setPosition(
        Math.round(window.frame.x + this.configuration.theme.dimensions.overlayXOffset),
        Math.round(window.frame.y + this.configuration.theme.dimensions.overlayYOffset)
      );
    } else {
      const primaryDisplay = screen.getPrimaryDisplay();
      this.overlayWindow?.setPosition(
        Math.round(primaryDisplay.bounds.x + this.configuration.theme.dimensions.overlayXOffset),
        Math.round(primaryDisplay.bounds.y + this.configuration.theme.dimensions.overlayYOffset)
      );
    }

    this.overlayWindow?.show();
    this.overlayWindow?.focus();
  }

  hideOverlay() {
    this.overlayWindow?.hide();
  }

  async closeDistraction(app: ActiveWindowInfo) {
    const monitor = new SystemMonitor();
    await monitor.initialize();

    const isBrowser = this.configuration.settings.monitoredBrowsers.some(browser =>
      app.processName.toLowerCase().includes(browser.toLowerCase())
    );

    if (isBrowser) {
      const identifier = app.bundleID || app.exeName || '';
      await monitor.closeBrowserTab(identifier);
    } else {
      await monitor.hideApplication(app.processName);
    }

    this.hideOverlay();
  }

  grantAccess(duration: number) {
    setTimeout(() => {
      this.hideOverlay();
    }, duration * 1000);
  }

  updateConfiguration(config: Configuration) {
    this.configuration = config;
  }
}
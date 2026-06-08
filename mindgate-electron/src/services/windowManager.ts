import { BrowserWindow, screen } from 'electron';
import type { Configuration, ActiveWindowInfo } from '../types.js';
import { SystemMonitor } from './platformWrapper.js';

export class WindowManager {
  private orbWindow: BrowserWindow | null = null;
  private overlayWindow: BrowserWindow | null = null;
  private configuration: Configuration;
  private targetApp: ActiveWindowInfo | null = null;
  private targetWindowFrame: ActiveWindowInfo['frame'] | null = null;

  constructor(configuration: Configuration) {
    this.configuration = configuration;
  }

  setOrbWindow(window: BrowserWindow) {
    this.orbWindow = window;
  }

  setOverlayWindow(window: BrowserWindow) {
    this.overlayWindow = window;
  }

  setTargetWindow(window: ActiveWindowInfo | null) {
    this.targetApp = window;
    if (window) {
      this.targetWindowFrame = window.frame;
    }
  }

  getTargetApp(): ActiveWindowInfo | null {
    return this.targetApp;
  }

  getOrbSize(): number {
    return this.configuration.theme.dimensions.orbSize;
  }

  getOrbXOffset(): number {
    return this.configuration.theme.dimensions.orbXOffset;
  }

  createOrbWindow(): BrowserWindow {
    const primaryDisplay = screen.getPrimaryDisplay();
    const { bounds } = primaryDisplay;

    this.orbWindow = new BrowserWindow({
      x: Math.round(bounds.x + this.configuration.theme.dimensions.orbXOffset),
      y: Math.round(bounds.y + bounds.height - this.configuration.theme.dimensions.orbSize - this.configuration.theme.dimensions.orbYOffset - 100),
      width: this.configuration.theme.dimensions.orbSize,
      height: this.configuration.theme.dimensions.orbSize,
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
        transparent: true
      }
    });

    return this.orbWindow;
  }

  createOverlayWindow(frame: { x: number; y: number; width: number; height: number }): BrowserWindow {
    this.overlayWindow = new BrowserWindow({
      x: Math.round(frame.x),
      y: Math.round(frame.y),
      width: Math.round(frame.width),
      height: Math.round(frame.height),
      transparent: true,
      frame: false,
      alwaysOnTop: true,
      skipTaskbar: true,
      resizable: false,
      movable: false,
      hasShadow: false,
      focusable: false
    });

    this.overlayWindow.setIgnoreMouseEvents(true);
    this.overlayWindow.setOpacity(0.85);
    return this.overlayWindow;
  }

  showOrb(targetWindow?: ActiveWindowInfo) {
    console.log('showOrb called with target:', targetWindow?.processName);
    if (targetWindow && targetWindow.frame.width > 0) {
      this.targetWindowFrame = targetWindow.frame;
    }

    if (!this.orbWindow) {
      console.log('Creating new orb window');
      this.createOrbWindow();
    }

    if (this.targetWindowFrame && this.targetWindowFrame.width > 0) {
      console.log('Positioning orb at:', this.targetWindowFrame.x, this.targetWindowFrame.width);
      this.orbWindow?.setPosition(
        Math.round(this.targetWindowFrame.x + this.targetWindowFrame.width - this.configuration.theme.dimensions.orbExpandedWidth - this.configuration.theme.dimensions.orbXOffset),
        Math.round(this.targetWindowFrame.y + this.configuration.theme.dimensions.orbYOffset)
      );
    }

    this.orbWindow?.setSize(
      this.configuration.theme.dimensions.orbExpandedWidth,
      this.configuration.theme.dimensions.orbExpandedHeight
    );
    this.orbWindow?.show();
    this.orbWindow?.focus();
    console.log('Orb window shown and focused');
    
    // CRITICAL: Focus webContents to ensure keyboard input is received
    this.orbWindow?.webContents?.focus();
    
    // Backup focus after a small delay to handle race conditions
    setTimeout(() => {
      this.orbWindow?.webContents?.focus();
    }, 50);
  }

  hideOrb() {
    this.orbWindow?.setSize(
      this.configuration.theme.dimensions.orbSize,
      this.configuration.theme.dimensions.orbSize
    );
    this.orbWindow?.hide();
  }

  showOverlay(targetWindow?: ActiveWindowInfo) {
    const window = targetWindow ?? this.targetApp;
    if (!window || !window.frame || window.frame.width === 0) {
      return;
    }

    if (!this.overlayWindow) {
      this.createOverlayWindow(window.frame);
    } else {
      this.overlayWindow.setPosition(Math.round(window.frame.x), Math.round(window.frame.y));
      this.overlayWindow.setSize(Math.round(window.frame.width), Math.round(window.frame.height));
    }
    
    // Ensure overlay ignores mouse events so it doesn't intercept input
    this.overlayWindow?.setIgnoreMouseEvents(true);
    
    this.overlayWindow?.show();
    this.orbWindow?.webContents.send('show-overlay');
  }

  hideOverlay() {
    this.overlayWindow?.hide();
    this.orbWindow?.webContents.send('hide-overlay');
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

    this.hideOrb();
    this.hideOverlay();
  }

  grantAccess(duration: number) {
    setTimeout(() => {
      this.hideOrb();
    }, duration * 1000);
  }

  updateConfiguration(config: Configuration) {
    this.configuration = config;
  }
}
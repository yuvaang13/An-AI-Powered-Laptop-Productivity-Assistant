import { BrowserWindow, screen, shell } from 'electron';
import { Configuration } from '../types';

export class WindowManager {
  private orbWindow: BrowserWindow | null = null;
  private overlayWindow: BrowserWindow | null = null;
  private mainWindow: BrowserWindow | null = null;
  private configuration: Configuration;
  private isOrbExpanded = false;
  private targetWindowId: number | null = null;

  constructor(configuration: Configuration) {
    this.configuration = configuration;
  }

  setMainWindow(window: BrowserWindow) {
    this.mainWindow = window;
  }

  createOrbWindow(): BrowserWindow {
    const primaryDisplay = screen.getPrimaryDisplay();
    const { x, y } = this.getOrbPosition(primaryDisplay);

    this.orbWindow = new BrowserWindow({
      x,
      y,
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
      minimizable: false,
      maximizable: false,
      webPreferences: {
        transparent: true
      }
    });

    return this.orbWindow;
  }

  createOverlayWindow(frame: Electron.Rectangle): BrowserWindow {
    this.overlayWindow = new BrowserWindow({
      x: frame.x,
      y: frame.y,
      width: frame.width,
      height: frame.height,
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
    return this.overlayWindow;
  }

  private getOrbPosition(display: Electron.Display): { x: number; y: number } {
    const { visibleArea } = display;
    const offset = this.configuration.theme.dimensions.orbDistractionOffset;
    
    return {
      x: visibleArea.x + this.configuration.theme.dimensions.orbXOffset + offset,
      y: visibleArea.y + visibleArea.height - this.configuration.theme.dimensions.orbSize - this.configuration.theme.dimensions.orbYOffset - 100
    };
  }

  async showOrb(targetWindowId?: number) {
    this.targetWindowId = targetWindowId ?? null;
    this.isOrbExpanded = true;
    
    if (!this.orbWindow) {
      this.createOrbWindow();
    }
    
    this.orbWindow?.setSize(
      this.configuration.theme.dimensions.orbExpandedWidth,
      this.configuration.theme.dimensions.orbExpandedHeight
    );
    this.orbWindow?.show();
    this.orbWindow?.focus();
  }

  hideOrb() {
    this.isOrbExpanded = false;
    if (this.orbWindow) {
      this.orbWindow.setSize(
        this.configuration.theme.dimensions.orbSize,
        this.configuration.theme.dimensions.orbSize
      );
      this.orbWindow.hide();
    }
  }

  showOverlay(frame?: Electron.Rectangle) {
    const targetFrame = frame ?? this.getTargetWindowFrame();
    if (targetFrame && !this.overlayWindow) {
      this.createOverlayWindow(targetFrame);
    }
    this.overlayWindow?.show();
  }

  hideOverlay() {
    this.overlayWindow?.hide();
  }

  private getTargetWindowFrame(): Electron.Rectangle | null {
    const mousePoint = screen.getCursorScreenPoint();
    const displays = screen.getAllDisplays();
    
    for (const display of displays) {
      if (
        mousePoint.x >= display.bounds.x &&
        mousePoint.x <= display.bounds.x + display.bounds.width &&
        mousePoint.y >= display.bounds.y &&
        mousePoint.y <= display.bounds.y + display.bounds.height
      ) {
        return display.bounds;
      }
    }
    
    return null;
  }

  grantAccess(duration: number) {
    setTimeout(() => {
      this.hideOrb();
    }, duration * 1000);
  }
}
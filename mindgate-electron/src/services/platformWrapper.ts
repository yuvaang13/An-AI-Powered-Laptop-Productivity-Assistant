import type { ActiveWindowInfo } from '../types';

export interface PlatformMonitor {
  getActiveWindow(): Promise<ActiveWindowInfo | null>;
  getActiveBrowserURL?(identifier: string): Promise<string | null>;
  closeBrowserTab?(identifier: string): Promise<boolean>;
  hideApplication?(processName: string): Promise<boolean>;
}

export class SystemMonitor {
  private platformMonitor: PlatformMonitor | null = null;

  async initialize() {
    if (process.platform === 'win32') {
      const { WindowsMonitor } = await import('../platform/windows/monitor');
      this.platformMonitor = new WindowsMonitor();
    } else if (process.platform === 'darwin') {
      const { MacMonitor } = await import('../platform/mac/monitor');
      this.platformMonitor = new MacMonitor();
    } else {
      const { LinuxMonitor } = await import('../platform/linux/monitor');
      this.platformMonitor = new LinuxMonitor();
    }
  }

  async getActiveWindow(): Promise<ActiveWindowInfo | null> {
    if (!this.platformMonitor) {
      await this.initialize();
    }
    return this.platformMonitor?.getActiveWindow() ?? null;
  }

  async getActiveBrowserURL(identifier: string): Promise<string | null> {
    if (!this.platformMonitor) {
      await this.initialize();
    }
    return this.platformMonitor?.getActiveBrowserURL?.(identifier) ?? null;
  }

  async closeBrowserTab(identifier: string): Promise<boolean> {
    if (!this.platformMonitor) {
      await this.initialize();
    }
    return this.platformMonitor?.closeBrowserTab?.(identifier) ?? false;
  }

  async hideApplication(processName: string): Promise<boolean> {
    if (!this.platformMonitor) {
      await this.initialize();
    }
    return this.platformMonitor?.hideApplication?.(processName) ?? false;
  }
}
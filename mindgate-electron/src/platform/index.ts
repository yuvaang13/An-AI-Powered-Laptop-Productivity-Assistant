import type { ActiveWindowInfo } from '../types';

export interface PlatformMonitor {
  getActiveWindow(): Promise<ActiveWindowInfo | null>;
  getActiveBrowserURL?(identifier: string): Promise<string | null>;
  closeBrowserTab?(identifier: string): Promise<boolean>;
  hideApplication?(processName: string): Promise<boolean>;
}
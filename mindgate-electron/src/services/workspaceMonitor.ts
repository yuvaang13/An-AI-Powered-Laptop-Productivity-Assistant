import type { ActiveWindowInfo, Configuration } from '../types.js';
import type { DecisionEngine } from './decisionEngine.js';
import type { SystemMonitor } from './platformWrapper.js';

export class WorkspaceMonitor {
  private monitor: SystemMonitor;
  private configuration: Configuration;
  private decisionEngine: DecisionEngine | null = null;
  private lastCheckTime: number = 0;
  private lastWindow: ActiveWindowInfo | null = null;
  private debounceInterval: number = 0.75;
  private promptRepeatInterval: number = 20;
  private lastPromptTime: number = 0;
  private activePromptIdentifier: string | null = null;
  private hasInitialCheckRun: boolean = false;

  constructor(configuration: Configuration, monitor: SystemMonitor) {
    this.configuration = configuration;
    this.monitor = monitor;
  }

  setDecisionEngine(engine: DecisionEngine): void {
    this.decisionEngine = engine;
  }

  getCurrentConfiguration(): Configuration {
    return this.configuration;
  }

  updateConfiguration(config: Configuration) {
    this.configuration = config;
  }

  async checkWorkspace(): Promise<boolean> {
    const now = Date.now() / 1000;

    if (now - this.lastCheckTime < this.debounceInterval) {
      return false;
    }
    this.lastCheckTime = now;

    const activeWindow = await this.monitor.getActiveWindow();
    if (!activeWindow) {
      console.log('No active window detected');
      return false;
    }

    console.log('Active window:', activeWindow.processName, '| Title:', activeWindow.windowTitle);

    if (this.hasInitialCheckRun &&
        activeWindow.processName === this.lastWindow?.processName &&
        activeWindow.windowTitle === this.lastWindow?.windowTitle) {
      return false;
    }

    if (!this.hasInitialCheckRun) {
      this.hasInitialCheckRun = true;
    }

    this.lastWindow = activeWindow;
    const identifier = this.getAppIdentifier(activeWindow);

    const isDistracting = this.isDistracting(activeWindow);
    console.log('Is distracting?', isDistracting);

    if (isDistracting) {
      if (this.decisionEngine?.hasActiveAccess(activeWindow)) {
        console.log('Access already granted for', activeWindow.processName);
        return false;
      }

      const timeSinceLastPrompt = now - this.lastPromptTime;
      if (timeSinceLastPrompt > this.promptRepeatInterval || this.lastPromptTime === 0) {
        this.lastPromptTime = now;
        this.activePromptIdentifier = identifier;
        this.onDistractionDetected?.(activeWindow);
        return true;
      }
    } else if (this.activePromptIdentifier === identifier) {
      this.clearActivePrompt();
    }

    return false;
  }

  getAppIdentifier(window: ActiveWindowInfo): string {
    return window.bundleID || window.exeName || window.processName;
  }

  private clearActivePrompt(): void {
    this.activePromptIdentifier = null;
    this.onClearPrompt?.();
  }

  private isDistracting(window: ActiveWindowInfo): boolean {
    const processName = window.processName.toLowerCase();
    const bundleID = window.bundleID?.toLowerCase() || '';
    const exeName = window.exeName?.toLowerCase() || '';

    if (this.configuration.settings.distractingApps.some(app =>
      processName.includes(app.toLowerCase()) || bundleID.includes(app.toLowerCase()) || exeName.includes(app.toLowerCase())
    )) {
      return true;
    }

    if (this.isBrowser(window) && this.hasRestrictedContent(window)) {
      return true;
    }

    return false;
  }

  private isBrowser(window: ActiveWindowInfo): boolean {
    const processName = window.processName.toLowerCase();
    const exeName = window.exeName?.toLowerCase() || '';
    const bundleID = window.bundleID?.toLowerCase() || '';
    
    return this.configuration.settings.monitoredBrowsers.some(browser =>
      processName.includes(browser.toLowerCase()) || exeName.includes(browser.toLowerCase()) || bundleID.includes(browser.toLowerCase())
    );
  }

  private hasRestrictedContent(window: ActiveWindowInfo): boolean {
    const windowTitle = window.windowTitle.toLowerCase();
    const browserURL = window.browserURL?.toLowerCase() || '';

    return this.configuration.settings.restrictedKeywords.some(kw => {
      const keyword = kw.toLowerCase();
      if (windowTitle.includes(keyword)) return true;
      if (browserURL.includes(keyword)) return true;
      try {
        const hostname = new URL(browserURL).hostname;
        if (hostname.includes(keyword)) return true;
      } catch {}
      return false;
    });
  }

  onDistractionDetected?: (window: ActiveWindowInfo) => void;
  onClearPrompt?: () => void;

  startMonitoring(intervalMs: number = 1000): void {
    console.log('Workspace monitoring started');
    this.checkWorkspace().catch(err => {
      console.error('Initial workspace check failed:', err);
    });
    setInterval(async () => {
      try {
        const result = await this.checkWorkspace();
        console.log('Workspace check completed, distraction:', result);
      } catch (err) {
        console.error('Workspace check failed:', err);
      }
    }, intervalMs);
  }
}
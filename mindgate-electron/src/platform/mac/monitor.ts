import { exec } from 'child_process';
import { promisify } from 'util';
import { ActiveWindowInfo } from '../../types.js';

const execAsync = promisify(exec);

export class MacMonitor {
  private hasPermission: boolean = true;

  setPermissionsGranted(): void {
    this.hasPermission = true;
  }

  async getActiveWindow(): Promise<ActiveWindowInfo | null> {
    if (!this.hasPermission) {
      console.log('[MacMonitor] No permission — returning null');
      return null;
    }

    // ── 1. Frontmost app name (works without Accessibility) ──
    let processName = 'unknown';
    try {
      const appScript = `tell application "System Events"
  set frontApp to name of first application process whose frontmost is true
  return frontApp
end tell`;
      const { stdout } = await execAsync(`osascript -e '${appScript}'`, { timeout: 5000 });
      processName = stdout.trim() || 'unknown';
    } catch {
      console.error('[MacMonitor] Failed to get frontmost app name');
      return null;
    }

    // ── 2. Window title ──
    // Strategy A: tell the app directly (works without Accessibility for apps
    //             that support AppleScript — Chrome, Safari, Firefox, etc.)
    // Strategy B: AXTitle via System Events (needs Accessibility)
    let windowTitle = '';
    try {
      const titleScript = `tell application "System Events"
  set frontApp to name of first application process whose frontmost is true
end tell
try
  tell application frontApp
    if (count of windows) > 0 then
      set windowTitle to name of front window
      return windowTitle
    end if
  end tell
end try
return ""`;
      const { stdout } = await execAsync(`osascript -e '${titleScript}'`, { timeout: 5000 });
      windowTitle = stdout.trim() || '';
    } catch {
      // Fallback to AXTitle
      try {
        const axScript = `tell application "System Events"
  set frontApp to first application process whose frontmost is true
  try
    set frontWindow to value of attribute "AXTitle" of front window of frontApp
    return frontWindow
  on error
    return ""
  end try
end tell`;
        const { stdout } = await execAsync(`osascript -e '${axScript}'`, { timeout: 5000 });
        windowTitle = stdout.trim() || '';
      } catch {
        // Title is optional
      }
    }

    // ── 3. Bundle ID (needs Accessibility on some macOS versions) ──
    let bundleID = '';
    try {
      const bundleScript = `tell application "System Events"
  try
    set frontAppPath to path to frontmost application as text
    set appInfo to info for frontAppPath
    return bundle identifier of appInfo
  on error
    return ""
  end try
end tell`;
      const { stdout } = await execAsync(`osascript -e '${bundleScript}'`, { timeout: 5000 });
      bundleID = stdout.trim() || '';
    } catch {
      // Bundle ID is optional
    }

    // ── 4. Window frame (optional) ──
    let frame = { x: 0, y: 0, width: 0, height: 0 };
    try {
      const frameScript = `tell application "System Events"
  set frontApp to first application process whose frontmost is true
  try
    set frontWindow to value of attribute "AXFrame" of front window of frontApp
    return frontWindow
  on error
    return "0,0,0,0"
  end try
end tell`;
      const frameResult = await execAsync(`osascript -e '${frameScript}'`, { timeout: 5000 });
      const frameParts = frameResult.stdout.trim().split(',').map(p => parseFloat(p.trim()));
      if (frameParts.length >= 4) {
        const mainScreenHeight = await this.getMainScreenHeight();
        frame = {
          x: frameParts[0] || 0,
          y: mainScreenHeight - (frameParts[1] || 0) - (frameParts[3] || 0),
          width: frameParts[2] || 0,
          height: frameParts[3] || 0
        };
      }
    } catch {
      // Frame is optional
    }

    // ── 5. Browser URL ──
    // Use bundle ID first, fall back to process name
    let browserURL: string | undefined;
    if (bundleID) {
      browserURL = (await this.getActiveBrowserURL(bundleID)) ?? undefined;
    }
    if (!browserURL && processName !== 'unknown') {
      browserURL = (await this.getActiveBrowserURL(processName)) ?? undefined;
    }

    console.log(`[MacMonitor] Window: "${processName}" | Title: "${windowTitle}" | BundleID: "${bundleID}" | URL: "${browserURL || ''}"`);

    return {
      processName,
      windowTitle,
      bundleID,
      browserURL,
      frame
    };
  }

  async getActiveBrowserURL(identifier: string): Promise<string | null> {
    if (!identifier) return null;

    try {
      const id = identifier.toLowerCase();
      // Bundle IDs look like "com.google.Chrome", process names look like "Google Chrome"
      const isBundleID = id.includes('.');
      const tellPrefix = isBundleID ? 'application id' : 'application';
      let script: string;

      if (id.includes('safari')) {
        script = `tell ${tellPrefix} "${identifier}"
  try
    if (count of windows) is 0 then return ""
    set tabURL to URL of current tab of front window
    return tabURL
  on error errMsg
    log "Safari URL error: " & errMsg
    return ""
  end try
end tell`;
      } else if (id.includes('chrome') || id.includes('brave') || id.includes('edge')) {
        script = `tell ${tellPrefix} "${identifier}"
  try
    if (count of windows) is 0 then return ""
    set frontTab to active tab of front window
    return URL of frontTab
  on error errMsg
    log "Chrome URL error: " & errMsg
    return ""
  end try
end tell`;
      } else if (id.includes('firefox')) {
        script = `tell ${tellPrefix} "${identifier}"
  try
    if (count of windows) is 0 then return ""
    set windowTitle to name of front window
    return windowTitle
  on error errMsg
    log "Firefox URL error: " & errMsg
    return ""
  end try
end tell`;
      } else {
        return null;
      }

      console.log(`[MacMonitor] Fetching URL for: ${identifier} (${tellPrefix})`);
      const { stdout } = await execAsync(`osascript -e '${script}'`, { timeout: 3000 });
      const result = stdout.trim();
      console.log(`[MacMonitor] URL fetch result: "${result}"`);

      return result || null;
    } catch (error) {
      console.error('[MacMonitor] Failed to get browser URL:', error);
      return null;
    }
  }

  async closeBrowserTab(identifier: string): Promise<boolean> {
    if (!identifier) return false;

    try {
      const id = identifier.toLowerCase();
      const isBundleID = id.includes('.');
      const tellPrefix = isBundleID ? 'application id' : 'application';
      let script: string;

      if (id.includes('chrome') || id.includes('brave') || id.includes('edge')) {
        script = `tell ${tellPrefix} "${identifier}" to close active tab of front window`;
      } else if (id.includes('safari')) {
        script = `tell ${tellPrefix} "${identifier}" to close current tab of front window`;
      } else if (id.includes('firefox')) {
        script = `tell ${tellPrefix} "${identifier}" to close front window`;
      } else {
        return false;
      }

      await execAsync(`osascript -e '${script}'`, { timeout: 3000 });
      return true;
    } catch (error) {
      console.error('Failed to close browser tab:', error);
      return false;
    }
  }

  async hideApplication(processName: string): Promise<boolean> {
    try {
      const script = `tell application "${processName}" to hide`;
      await execAsync(`osascript -e '${script}'`, { timeout: 3000 });
      return true;
    } catch (error) {
      console.error('Failed to hide application:', error);
      return false;
    }
  }

  private async getMainScreenHeight(): Promise<number> {
    const { stdout } = await execAsync('system_profiler SPDisplaysDataType | grep "Resolution" | head -1 | awk \'{print $2}\'', { timeout: 2000 });
    const match = stdout.match(/(\d+)/);
    return match ? parseInt(match[1], 10) : 1080;
  }
}

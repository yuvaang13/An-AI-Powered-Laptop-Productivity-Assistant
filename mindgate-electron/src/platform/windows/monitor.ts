import { exec } from 'child_process';
import { promisify } from 'util';
import { ActiveWindowInfo } from '../../types';

const execAsync = promisify(exec);

export class WindowsMonitor {
  async getActiveWindow(): Promise<ActiveWindowInfo | null> {
    try {
      const psScript = `
Add-Type @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
public class Win32 {
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [DllImport("user32.dll")]
  public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
}
public struct RECT {
  public int Left, Top, Right, Bottom;
}
"@
$hwnd = [Win32]::GetForegroundWindow()
$rect = New-Object RECT
[Win32]::GetWindowRect($hwnd, [ref]$rect)
$processId = 0
[Win32]::GetWindowThreadProcessId($hwnd, [ref]$processId)
$process = Get-Process -Id $processId -ErrorAction SilentlyContinue
$sb = New-Object Text.StringBuilder(256)
[Win32]::GetWindowText($hwnd, $sb, 256)
if ($process) {
  "$($process.ProcessName)|$($sb.ToString())|$($rect.Left)|$($rect.Top)|$($rect.Right-$rect.Left)|$($rect.Bottom-$rect.Top)|$($process.MainModule.ModuleName)"
}
`;
      const { stdout } = await execAsync(`powershell -ExecutionPolicy Bypass -Command "${psScript.replace(/"/g, '\\"')}"`, { timeout: 5000 });

      if (!stdout?.trim()) {
        return null;
      }

      const parts = stdout.trim().split('|');
      const [processName, windowTitle, x, y, width, height, exeName] = parts;

      return {
        processName: processName || 'unknown',
        windowTitle: windowTitle || '',
        exeName: exeName || '',
        frame: {
          x: parseInt(x, 10) || 0,
          y: parseInt(y, 10) || 0,
          width: parseInt(width, 10) || 0,
          height: parseInt(height, 10) || 0
        }
      };
    } catch (error) {
      console.error('Failed to get active window on Windows:', error);
      return null;
    }
  }

  async getActiveBrowserURL(exeName: string): Promise<string | null> {
    if (!exeName) return null;

    try {
      let script: string;
      const normalizedExe = exeName.toLowerCase();

      if (normalizedExe.includes('chrome') || normalizedExe.includes('msedge') || normalizedExe.includes('brave')) {
        script = `
$process = Get-Process -Name "$([System.IO.Path]::GetFileNameWithoutExtension('${exeName}'))" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$url = ""
foreach ($proc in $process) {
  try {
    $url = (Get-ItemProperty -Path "HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\Browser\\Session\\" -ErrorAction SilentlyContinue).Url
  } catch {}
}
Write-Output $url
`;
      } else if (normalizedExe.includes('firefox')) {
        script = `
$process = Get-Process -Name "firefox" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$url = ""
if ($process) {
  try {
    $url = (Get-Process -Name "firefox" -ErrorAction SilentlyContinue).MainWindowTitle -replace " - Mozilla Firefox$", ""
  } catch {}
}
Write-Output $url
`;
      } else {
        return null;
      }

      const { stdout } = await execAsync(`powershell -ExecutionPolicy Bypass -Command "${script.replace(/"/g, '\\"')}"`, { timeout: 3000 });
      return stdout.trim() || null;
    } catch (error) {
      console.error('Failed to get browser URL:', error);
      return null;
    }
  }

  async closeBrowserTab(exeName: string): Promise<boolean> {
    if (!exeName) return false;

    try {
      const script = `
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Diagnostics;
"@
$processes = Get-Process -Name "$([System.IO.Path]::GetFileNameWithoutExtension('${exeName}'))" -ErrorAction SilentlyContinue
foreach ($proc in $processes) {
  try {
    $proc.CloseMainWindow() | Out-Null
  } catch {}
}
`;
      await execAsync(`powershell -ExecutionPolicy Bypass -Command "${script.replace(/"/g, '\\"')}"`, { timeout: 3000 });
      return true;
    } catch (error) {
      console.error('Failed to close browser tab:', error);
      return false;
    }
  }

  async hideApplication(processName: string): Promise<boolean> {
    try {
      const script = `
$process = Get-Process -Name "${processName}" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($process) {
  $process | ForEach-Object {
    $_.CloseMainWindow() | Out-Null
  }
}
`;
      await execAsync(`powershell -ExecutionPolicy Bypass -Command "${script.replace(/"/g, '\\"')}"`, { timeout: 3000 });
      return true;
    } catch (error) {
      console.error('Failed to hide application:', error);
      return false;
    }
  }
}
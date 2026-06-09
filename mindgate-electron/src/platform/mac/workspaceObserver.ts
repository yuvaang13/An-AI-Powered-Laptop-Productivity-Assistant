import { ChildProcess, spawn } from 'child_process';
import { EventEmitter } from 'events';
import { writeFileSync, unlinkSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';

/**
 * Observes macOS workspace for app activation events.
 *
 * Primary: Spawns a long-lived JXA process that subscribes to
 *   NSWorkspaceDidActivateApplicationNotification — zero CPU when idle.
 *
 * Fallback: If JXA is unavailable, spawns a single AppleScript process
 *   with a 1-second `delay` loop (1 osascript, ~1 check/sec — still
 *   far more efficient than the old 4–7 osascripts every 500ms).
 */
export class WorkspaceObserver extends EventEmitter {
  private process: ChildProcess | null = null;
  private scriptPath: string | null = null;
  private restartTimer: NodeJS.Timeout | null = null;
  private useFallback: boolean = false;
  private stopped: boolean = false;

  start(): void {
    if (this.process) return;
    this.stopped = false;
    this.tryJXA();
  }

  private tryJXA(): void {
    const script = [
      'ObjC.import("Cocoa");',
      'var nc = $.NSWorkspace.sharedWorkspace.notificationCenter;',
      'var obs = nc.addObserverForNameObjectQueueUsingBlock(',
      '    $.NSWorkspaceDidActivateApplicationNotification,',
      '    null,',
      '    null,',
      '    function(note){',
      '        var app = note.userInfo.objectForKey($.NSWorkspaceApplicationKey);',
      '        var name = app.localizedName.js;',
      '        $.NSFileHandle.fileHandleWithStandardOutput.writeData(',
      '            $.NSString.alloc.initWithString(name+"\\n").dataUsingEncoding($.NSUTF8StringEncoding)',
      '        );',
      '    }',
      ');',
      '$.NSRunLoop.currentRunLoop.runUntilDate($.NSDate.distantFuture);',
    ].join('\n');
    this.spawn('osascript', ['-l', 'JavaScript', this.writeScript(script)]);
  }

  private startFallback(): void {
    const script = [
      'set prevApp to ""',
      'repeat',
      '    tell application "System Events"',
      '        try',
      '            set frontApp to name of first application process whose frontmost is true',
      '            if frontApp is not prevApp then',
      '                set prevApp to frontApp',
      '                return frontApp',
      '            end if',
      '        end try',
      '    end tell',
      '    delay 1',
      'end repeat',
    ].join('\n');
    this.spawn('osascript', ['-e', script], false);
  }

  private writeScript(content: string): string {
    this.cleanupTempFile();
    this.scriptPath = join(tmpdir(), `mindgate-ws-${Date.now()}.jxa`);
    writeFileSync(this.scriptPath, content, 'utf-8');
    return this.scriptPath;
  }

  private spawn(bin: string, args: string[], captureLineMode: boolean = true): void {
    this.process = spawn(bin, args, {
      stdio: ['ignore', 'pipe', 'pipe'],
    });

    let stdoutBuf = '';

    this.process.stdout?.on('data', (data: Buffer) => {
      stdoutBuf += data.toString('utf-8');
      if (!captureLineMode) return;

      const lines = stdoutBuf.split('\n');
      stdoutBuf = lines.pop() || '';
      for (const line of lines) {
        const appName = line.trim();
        if (appName) {
          this.emit('app-activated', appName);
        }
      }
    });

    this.process.stderr?.on('data', (data: Buffer) => {
      const msg = data.toString().trim();
      if (msg) {
        console.error('[WorkspaceObserver]', msg);
        stdoutBuf += msg + '\n';
        if (captureLineMode) {
          const lines = stdoutBuf.split('\n');
          stdoutBuf = lines.pop() || '';
          for (const line of lines) {
            const appName = line.trim();
            if (appName) {
              this.emit('app-activated', appName);
            }
          }
        }
      }
    });

    this.process.on('exit', (code) => {
      const proc = this.process;
      this.process = null;
      if (this.stopped || proc?.killed) return;

      if (!this.useFallback && code !== 0) {
        console.log('[WorkspaceObserver] JXA failed (exit', code, ')—falling back to AppleScript polling');
        this.useFallback = true;
        this.startFallback();
      } else if (code !== 0) {
        console.log('[WorkspaceObserver] Process exited with code', code, '—restarting in 2s');
        this.restartTimer = setTimeout(() => this.startFallback(), 2000);
      }
    });

    this.process.on('error', (err) => {
      this.process = null;
      if (this.stopped) return;

      if (!this.useFallback) {
        console.log('[WorkspaceObserver] JXA error:', err.message, '—falling back to AppleScript polling');
        this.useFallback = true;
        this.startFallback();
      } else {
        console.log('[WorkspaceObserver] Process error:', err.message, '—restarting in 2s');
        this.restartTimer = setTimeout(() => this.startFallback(), 2000);
      }
    });
  }

  stop(): void {
    this.stopped = true;
    if (this.restartTimer) {
      clearTimeout(this.restartTimer);
      this.restartTimer = null;
    }
    if (this.process) {
      this.process.kill('SIGTERM');
      this.process = null;
    }
    this.cleanupTempFile();
    this.removeAllListeners();
  }

  private cleanupTempFile(): void {
    if (this.scriptPath) {
      try {
        unlinkSync(this.scriptPath);
      } catch {
        // best effort
      }
      this.scriptPath = null;
    }
  }
}

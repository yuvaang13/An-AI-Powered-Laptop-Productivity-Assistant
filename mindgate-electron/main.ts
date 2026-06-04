import { app, BrowserWindow, ipcMain, screen } from 'electron';
import { join } from 'path';
import { WindowManager } from './src/services/windowManager';
import { OllamaService } from './src/services/ollamaService';
import { Configuration } from './src/types';

const configuration: Configuration = {
  settings: {
    distractingApps: ['Discord', 'Slack', 'Twitter', 'Telegram', 'Reddit'],
    restrictedKeywords: ['youtube', 'twitter', 'facebook', 'instagram'],
    monitoredBrowsers: ['Safari', 'Google Chrome', 'Firefox', 'Brave', 'Microsoft Edge'],
    ollamaURL: 'http://localhost:11434/api/generate',
    ollamaModel: 'gemma3:1b',
    accessDurations: [300, 600, 900],
    accessDurationLabels: ['5 Mins', '10 Mins', '15 Mins'],
    productiveTasks: ['Review tasks', 'Plan next steps'],
    productiveApps: ['Notes', 'Calendar'],
    justificationCountdownDuration: 15
  },
  theme: {
    colors: {
      primary: '#FFFFFF',
      secondary: '#FFFFFFB3',
      accent: '#FFFFFF99',
      background: '#000000',
      surface: '#000000',
      text: '#FFFFFF',
      textSecondary: '#FFFFFFB3',
      error: '#FF453A',
      warning: '#FF9F0A'
    },
    animation: {
      orbBreathingDuration: 3.0,
      orbTransitionDuration: 0.3,
      overlayFadeDuration: 0.5
    },
    dimensions: {
      orbSize: 60,
      orbExpandedWidth: 380,
      orbExpandedHeight: 380,
      chatCornerRadius: 180,
      orbXOffset: 12,
      orbYOffset: 12,
      orbDistractionOffset: 50
    }
  }
};

const windowManager = new WindowManager(configuration);
const ollamaService = new OllamaService(configuration.settings.ollamaURL, configuration.settings.ollamaModel);

function createWindow() {
  const mainWindow = new BrowserWindow({
    width: 400,
    height: 600,
    webPreferences: {
      preload: join(__dirname, '../preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  if (process.env.VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(process.env.VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(join(__dirname, '../dist/index.html'));
  }

  windowManager.setMainWindow(mainWindow);
}

app.whenReady().then(() => {
  createWindow();

  ipcMain.handle('check-ollama-connection', async () => {
    return await ollamaService.checkConnection();
  });

  ipcMain.handle('evaluate-request', async (_event, userInput: string) => {
    return await ollamaService.evaluateRequest(userInput);
  });

  ipcMain.handle('grant-access', (_event, duration: number) => {
    windowManager.grantAccess(duration);
  });

  ipcMain.handle('get-configuration', () => {
    return configuration;
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});
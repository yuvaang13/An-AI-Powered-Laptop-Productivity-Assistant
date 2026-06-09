import './index.css';
import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { Settings } from './components/settings/Settings';
import type { Configuration } from './types';

const urlParams = new URLSearchParams(window.location.search);
const isSettingsWindow = urlParams.get('settings') === 'true';

const RootComponent: React.FC = () => {
  const [configuration, setConfiguration] = React.useState<Configuration | null>(null);
  const [loading, setLoading] = React.useState(isSettingsWindow);

  React.useEffect(() => {
    if (isSettingsWindow) {
      window.mindgateAPI.getConfiguration().then(setConfiguration);
      setLoading(false);
    }
  }, []);

  if (isSettingsWindow) {
    if (loading || !configuration) return null;
    return React.createElement(Settings as any, { configuration });
  }
  return React.createElement(App);
};

createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <RootComponent />
  </React.StrictMode>
);
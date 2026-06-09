import React, { useEffect, useState } from 'react';
import { Configuration } from './types';
import './styles/glassmorphism.css';
import { LiquidGlassOverlay } from './components/overlay/Overlay';

const App: React.FC = () => {
  const [configuration, setConfiguration] = useState<Configuration | null>(null);
  const [isOverlayVisible, setIsOverlayVisible] = useState(false);
  const [isOllamaConnected, setIsOllamaConnected] = useState(true);

  useEffect(() => {
    window.mindgateAPI.getConfiguration().then(setConfiguration);
  }, []);

  useEffect(() => {
    window.mindgateAPI.onShowOverlay(() => {
      setIsOverlayVisible(true);
    });

    window.mindgateAPI.onHideOverlay(() => {
      setIsOverlayVisible(false);
    });

    window.mindgateAPI.onOllamaStatusChanged((connected) => {
      setIsOllamaConnected(connected);
    });
  }, []);

  const handleClose = () => {
    setIsOverlayVisible(false);
    window.mindgateAPI.hideOverlay();
  };

  if (!configuration) {
    return null;
  }

  return (
    <>
      {!isOllamaConnected && (
        <div style={{
          position: 'fixed',
          top: '12px',
          right: '12px',
          background: 'rgba(255, 69, 58, 0.9)',
          color: 'white',
          padding: '8px 14px',
          borderRadius: '10px',
          fontSize: '13px',
          zIndex: 2147483647,
          backdropFilter: 'blur(10px)',
          WebkitBackdropFilter: 'blur(10px)'
        }}>
          Ollama Disconnected
        </div>
      )}
      <LiquidGlassOverlay
        visible={isOverlayVisible}
        configuration={configuration}
        onClose={handleClose}
      />
    </>
  );
};

export default App;
import React from 'react';
import { motion } from 'framer-motion';
import { Configuration } from '../../types';

interface TakeoverViewProps {
  configuration: Configuration;
  onDismiss: () => void;
}

export const TakeoverView: React.FC<TakeoverViewProps> = ({ configuration, onDismiss }) => {
  const handleOpenNewTab = () => {
    window.mindgateAPI.launchURL('https://www.google.com');
    onDismiss();
  };

  const handleOpenProductiveApp = () => {
    if (configuration.settings.productiveApps.length > 0) {
      const randomApp = configuration.settings.productiveApps[
        Math.floor(Math.random() * configuration.settings.productiveApps.length)
      ];
      window.mindgateAPI.launchApp(randomApp);
      onDismiss();
    }
  };

  return (
    <motion.div
      key="takeover"
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -10 }}
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 14,
        padding: '0 4px',
        pointerEvents: 'auto'
      }}
    >
      <div style={{ textAlign: 'center' }}>
        <div style={{
          fontSize: 36,
          marginBottom: 10,
          background: 'linear-gradient(135deg, #ffffff, #ffffffaa)',
          WebkitBackgroundClip: 'text',
          backgroundClip: 'text',
          WebkitTextFillColor: 'transparent'
        }}>
          ⛔
        </div>
        <h2 style={{
          fontSize: 24,
          fontWeight: 'bold',
          color: 'white',
          margin: 0,
          marginBottom: 6
        }}>
          Time to Refocus
        </h2>
        <p style={{
          fontSize: 14,
          color: 'rgba(255,255,255,0.7)',
          margin: 0,
          textAlign: 'center'
        }}>
          Your work is waiting for you.
        </p>
      </div>

      <div style={{ marginBottom: 8 }}>
        <p style={{
          fontSize: 13,
          fontWeight: 'semibold',
          color: 'rgba(255,255,255,0.8)',
          margin: '0 0 8px 0'
        }}>
          Productive Suggestions:
        </p>
        
        <div style={{
          maxHeight: 150,
          overflowY: 'auto',
          padding: 12,
          borderRadius: 14,
          background: 'rgba(255,255,255,0.07)',
          backdropFilter: 'blur(20px)',
          WebkitBackdropFilter: 'blur(20px)',
          border: '0.8px solid rgba(255,255,255,0.14)'
        }}>
          {configuration.settings.productiveTasks.map((task, index) => (
            <div key={index} style={{
              display: 'flex',
              alignItems: 'flex-start',
              gap: 6,
              marginBottom: index < configuration.settings.productiveTasks.length - 1 ? 6 : 0
            }}>
              <div style={{
                width: 5,
                height: 5,
                borderRadius: '50%',
                background: configuration.theme.colors.warning,
                marginTop: 8,
                flexShrink: 0
              }} />
              <span style={{
                fontSize: 13,
                color: 'rgba(255,255,255,0.75)',
                lineHeight: 1.4
              }}>
                {task}
              </span>
            </div>
          ))}
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={handleOpenNewTab}
          style={{
            flex: 1,
            padding: '8px 0',
            borderRadius: 16,
            background: 'linear-gradient(135deg, rgba(255,255,255,0.35), rgba(255,255,255,0.25))',
            border: 'none',
            color: 'white',
            fontSize: 13,
            cursor: 'pointer'
          }}
        >
          New Tab
        </button>
        
        <button
          onClick={handleOpenProductiveApp}
          style={{
            flex: 1,
            padding: '8px 0',
            borderRadius: 16,
            background: 'linear-gradient(135deg, rgba(255,255,255,0.35), rgba(255,255,255,0.25))',
            border: 'none',
            color: 'white',
            fontSize: 13,
            cursor: 'pointer'
          }}
        >
          Open App
        </button>
      </div>

      <button
        onClick={onDismiss}
        style={{
          padding: '8px 16px',
          borderRadius: 16,
          background: 'linear-gradient(135deg, rgba(255,255,255,0.35), rgba(255,255,255,0.25))',
          border: 'none',
          color: 'white',
          fontSize: 13,
          cursor: 'pointer',
          width: '100%'
        }}
      >
        Dismiss & Return to Work
      </button>
    </motion.div>
  );
};
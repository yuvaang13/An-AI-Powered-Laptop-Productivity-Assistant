import { Configuration } from '../../types';

interface TakeoverViewProps {
  configuration: Configuration | null;
  onDismiss: () => void;
}

export const TakeoverView = ({ configuration, onDismiss }: TakeoverViewProps) => {
  const handleOpenNewTab = () => {
    window.mindgateAPI?.launchURL?.('https://www.google.com');
    onDismiss();
  };

  const handleOpenProductiveApp = () => {
    const productiveApps = configuration?.settings?.productiveApps;
    if (productiveApps && productiveApps.length > 0) {
      const randomApp = productiveApps[Math.floor(Math.random() * productiveApps.length)];
      window.mindgateAPI?.launchApp?.(randomApp);
      onDismiss();
    }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, padding: '0 4px', pointerEvents: 'auto' }}>
      <div style={{ textAlign: 'center' }}>
        <h2 style={{ fontSize: 24, fontWeight: 'bold', color: '#000', margin: 0, marginBottom: 6 }}>
          Time to Refocus
        </h2>
        <p style={{ fontSize: 14, color: '#666', margin: 0, textAlign: 'center' }}>
          Your work is waiting for you.
        </p>
      </div>

      <div style={{ marginBottom: 8 }}>
        <p style={{ fontSize: 13, fontWeight: 600, color: '#333', margin: '0 0 8px 0' }}>
          Productive Suggestions:
        </p>

        <div style={{ maxHeight: 150, overflowY: 'auto', padding: 12, borderRadius: 4, background: '#f5f5f5', border: '1px solid #ddd' }}>
          {configuration?.settings?.productiveTasks && configuration.settings.productiveTasks.length > 0 ? (
            configuration.settings.productiveTasks.map((task, index) => (
              <div key={index} style={{ display: 'flex', alignItems: 'flex-start', gap: 6, marginBottom: index < configuration.settings.productiveTasks.length - 1 ? 6 : 0 }}>
                <span style={{ fontSize: 13, color: '#333', lineHeight: 1.4 }}>{task}</span>
              </div>
            ))
          ) : (
            <span style={{ fontSize: 13, color: '#666' }}>Review your priorities and get back to focused work.</span>
          )}
        </div>
      </div>

      <div style={{ display: 'flex', gap: 8 }}>
        <button
          onClick={handleOpenNewTab}
          style={{
            flex: 1,
            padding: '8px 0',
            borderRadius: 4,
            background: '#e0e0e0',
            border: 'none',
            color: '#000',
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
            borderRadius: 4,
            background: '#e0e0e0',
            border: 'none',
            color: '#000',
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
          borderRadius: 4,
          background: '#e0e0e0',
          border: 'none',
          color: '#000',
          fontSize: 13,
          cursor: 'pointer',
          width: '100%',
        }}
      >
        Dismiss & Return to Work
      </button>
    </div>
  );
};

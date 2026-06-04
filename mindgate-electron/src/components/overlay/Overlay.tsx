import React from 'react';

interface OverlayProps {
  visible: boolean;
}

export const Overlay: React.FC<OverlayProps> = ({ visible }) => {
  if (!visible) return null;

  return (
    <div
      style={{
        position: 'fixed',
        top: 0,
        left: 0,
        right: 0,
        bottom: 0,
        backgroundColor: 'rgba(0, 0, 0, 0.85)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        zIndex: 9999,
        pointerEvents: 'none'
      }}
    />
  );
};
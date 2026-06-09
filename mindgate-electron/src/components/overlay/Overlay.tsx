import React, { useState } from 'react';
import { Configuration, DecisionResult } from '../../types';
import { TakeoverView } from '../takeover/TakeoverView';

interface OverlayProps {
  visible: boolean;
  configuration: Configuration;
  onSubmit: (userInput: string) => Promise<DecisionResult | void>;
  onClose: () => void;
}

export const LiquidGlassOverlay: React.FC<OverlayProps> = ({ visible, configuration, onSubmit, onClose }) => {
  const [userInput, setUserInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [aiResponse, setAiResponse] = useState('');
  const [showDurationSelection, setShowDurationSelection] = useState(false);
  const [showDeniedMessage, setShowDeniedMessage] = useState(false);
  const [showTakeoverView, setShowTakeoverView] = useState(false);
  const [countdownSeconds, setCountdownSeconds] = useState(0);
  const [remainingAccessTime, setRemainingAccessTime] = useState<number | null>(null);
  const [isTextareaFocused, setIsTextareaFocused] = useState(false);

  React.useEffect(() => {
    if (visible) {
      setCountdownSeconds(configuration.settings.justificationCountdownDuration);
      setUserInput('');
      setAiResponse('');
      setIsLoading(false);
      setShowDurationSelection(false);
      setShowDeniedMessage(false);
      setShowTakeoverView(false);
    }
  }, [visible, configuration.settings.justificationCountdownDuration]);

  React.useEffect(() => {
    const timer = setInterval(() => {
      if (countdownSeconds > 0) {
        setCountdownSeconds(s => s - 1);
      } else if (countdownSeconds === 0 && !isLoading && !showDurationSelection && !showDeniedMessage && !aiResponse && userInput === '') {
        handleCountdownExpired();
      }
      
      if (showDurationSelection) {
        window.mindgateAPI.getRemainingAccessTime().then(time => {
          if (time > 0) {
            setRemainingAccessTime(time);
          }
        });
      }
    }, 1000);
    return () => clearInterval(timer);
  }, [countdownSeconds, isLoading, showDurationSelection, showDeniedMessage, aiResponse, userInput]);

  const handleTextareaFocus = () => setIsTextareaFocused(true);
  const handleTextareaBlur = () => setIsTextareaFocused(false);

  const handleSubmit = async () => {
    if (!userInput.trim() || isLoading) return;

    setIsLoading(true);
    try {
      const result = await onSubmit(userInput);
      if (!result) {
        setAiResponse('No response received');
        setShowDeniedMessage(true);
        handleDeniedMessageDismissed();
      } else if (result.isApproved) {
        setAiResponse(result.message);
        setShowDurationSelection(true);
      } else {
        setAiResponse(result.message);
        setShowDeniedMessage(true);
        handleDeniedMessageDismissed();
      }
    } catch {
      setAiResponse('Error: Unable to get AI response');
      setShowDeniedMessage(true);
      handleDeniedMessageDismissed();
    }
    setIsLoading(false);
  };

  const handleCountdownExpired = () => {
    setAiResponse("Time's up! Access denied.");
    setShowDeniedMessage(true);
    window.mindgateAPI.closeDistraction();
    setTimeout(() => onClose(), 2000);
  };

  const headlineText = () => {
    if (showDurationSelection) return 'Access granted';
    if (showDeniedMessage) return 'Access denied';
    if (isLoading) return 'Checking with AI';
    if (countdownSeconds > 0) return `Why are you here? (${countdownSeconds}s)`;
    return 'Why are you here?';
  };

  const selectDuration = (index: number) => {
    window.mindgateAPI.grantAccess(index);
    onClose();
    resetState();
  };

  const resetState = () => {
    setUserInput('');
    setAiResponse('');
    setIsLoading(false);
    setShowDurationSelection(false);
    setShowDeniedMessage(false);
    setShowTakeoverView(false);
    setCountdownSeconds(0);
    setRemainingAccessTime(null);
  };

  const handleDeniedMessageDismissed = () => {
    window.mindgateAPI.closeDistraction();
    setShowTakeoverView(true);
  };

  const handleTextChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setUserInput(e.target.value);
  };

  const handleKeyDown = (e: React.KeyboardEvent<HTMLTextAreaElement>) => {
    const isMetaOrCtrl = e.metaKey || e.ctrlKey;
    if (isMetaOrCtrl && e.key === 'Enter') {
      e.preventDefault();
      handleSubmit();
    }
  };

  if (!visible) return null;

  const content = () => {
    if (isLoading) {
      return (
        <div style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '10px' }}>
          <p style={{ color: '#333', margin: 0, fontSize: '13px' }}>AI is thinking...</p>
        </div>
      );
    }
    if (showDurationSelection) {
      return (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          <p style={{ fontSize: '13px', color: '#333', textAlign: 'center', margin: 0 }}>Choose duration:</p>
          {remainingAccessTime !== null && (
            <p style={{ fontSize: '11px', color: '#666', textAlign: 'center', margin: 0 }}>
              Access expires in: {remainingAccessTime}s
            </p>
          )}
          <div style={{ display: 'flex', gap: '8px' }}>
            {configuration.settings.accessDurationLabels.map((label, index) => (
              <button
                key={index}
                onClick={() => selectDuration(index)}
                style={{
                  flex: 1,
                  padding: '8px 0',
                  borderRadius: '4px',
                  background: '#e0e0e0',
                  border: 'none',
                  color: '#000',
                  cursor: 'pointer',
                  fontSize: '13px'
                }}
              >
                {label}
              </button>
            ))}
          </div>
        </div>
      );
    }
    if (aiResponse) {
      return (
        <div style={{ textAlign: 'center' }}>
          <p style={{ fontSize: '13px', color: '#333', lineHeight: 1.4 }}>{aiResponse}</p>
          <button
            onClick={() => {
              if (showDeniedMessage) {
                resetState();
                setCountdownSeconds(configuration.settings.justificationCountdownDuration);
              } else {
                onClose();
                resetState();
              }
            }}
            style={{
              marginTop: '14px',
              padding: '8px 16px',
              borderRadius: '4px',
              background: '#e0e0e0',
              border: 'none',
              color: '#000',
              cursor: 'pointer',
              fontSize: '13px'
            }}
          >
            {showDeniedMessage ? 'Try Again' : 'Close'}
          </button>
        </div>
      );
    }
    if (showTakeoverView) {
      return <TakeoverView configuration={configuration} onDismiss={() => { setShowTakeoverView(false); onClose(); resetState(); }} />;
    }
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
        <p style={{ fontSize: '13px', fontWeight: '500', color: '#333', textAlign: 'center', margin: 0 }}>Why do you need access?</p>
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: '8px', padding: '8px', borderRadius: '4px', background: '#f5f5f5', border: '1px solid #ddd' }}>
          <textarea
            value={userInput}
            onChange={handleTextChange}
            onFocus={handleTextareaFocus}
            onBlur={handleTextareaBlur}
            onKeyDown={handleKeyDown}
            placeholder="I need this because..."
            style={{
              flex: 1,
              background: 'transparent',
              border: isTextareaFocused ? '1px solid #888' : 'none',
              color: '#000',
              fontSize: '13px',
              resize: 'none',
              outline: 'none',
              minHeight: '48px',
              padding: '8px 12px',
              borderRadius: '4px'
            }}
            spellCheck="false"
          />
          <button
            onClick={handleSubmit}
            disabled={!userInput.trim() || isLoading}
            style={{
              width: '32px',
              height: '32px',
              borderRadius: '4px',
              background: userInput.trim() ? '#333' : '#ccc',
              border: 'none',
              color: '#fff',
              cursor: userInput.trim() ? 'pointer' : 'default',
              fontSize: '14px',
              flexShrink: 0
            }}
          >
            ↑
          </button>
        </div>
      </div>
    );
  };

  return (
    <div
      style={{
        position: 'fixed',
        top: '24px',
        left: '24px',
        width: configuration.theme.dimensions.overlayWidth,
        height: configuration.theme.dimensions.overlayHeight,
        background: '#ffffff',
        padding: '20px',
        display: 'flex',
        flexDirection: 'column',
        gap: '12px',
        pointerEvents: 'auto',
        zIndex: 2147483647
      }}
    >
      <h2 style={{ fontSize: '18px', fontWeight: '600', color: '#000', textAlign: 'center', margin: 0, marginTop: '4px' }}>
        {headlineText()}
      </h2>

      {!showDurationSelection && !showDeniedMessage && !isLoading && !aiResponse && (
        <p style={{ fontSize: '12px', color: '#666', textAlign: 'center', margin: 0 }}>Distraction detected. Explain why.</p>
      )}

      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
        {content()}
      </div>
    </div>
  );
};
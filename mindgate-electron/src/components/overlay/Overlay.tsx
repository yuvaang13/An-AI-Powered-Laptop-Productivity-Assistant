import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
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

  return (
    <AnimatePresence>
      <motion.div
        key="overlay"
        initial={{ opacity: 0, y: -20 }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: -20 }}
        transition={{ duration: configuration.theme.animation.transitionDuration }}
        style={{
          position: 'fixed',
          top: '24px',
          left: '24px',
width: configuration.theme.dimensions.overlayWidth,
      height: configuration.theme.dimensions.overlayHeight,
          borderRadius: '28px',
          background: 'rgba(10, 10, 12, 0.45)',
          backdropFilter: 'blur(24px) saturate(1.8)',
          WebkitBackdropFilter: 'blur(24px) saturate(1.8)',
          border: '1px solid rgba(255, 255, 255, 0.12)',
          boxShadow: '0 12px 48px rgba(0, 0, 0, 0.4), 0 0 0 0.5px rgba(255, 255, 255, 0.08) inset',
          padding: '20px',
          display: 'flex',
          flexDirection: 'column',
          gap: '12px',
          pointerEvents: 'auto',
          zIndex: 2147483647
        }}
      >
        <button
          onClick={onClose}
          style={{
            position: 'absolute',
            top: '16px',
            right: '16px',
            width: '28px',
            height: '28px',
            borderRadius: '50%',
            background: 'rgba(255, 255, 255, 0.15)',
            border: 'none',
            cursor: 'pointer',
            color: 'rgba(255, 255, 255, 0.7)',
            fontSize: '16px',
            fontWeight: 'bold',
            pointerEvents: 'auto',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center'
          }}
        >
          ×
        </button>

        <h2 style={{
          fontSize: '18px',
          fontWeight: '600',
          color: 'rgba(255, 255, 255, 0.95)',
          textAlign: 'center',
          margin: 0,
          marginTop: '4px'
        }}>
          {headlineText()}
        </h2>

        {!showDurationSelection && !showDeniedMessage && !isLoading && !aiResponse && (
          <p style={{
            fontSize: '12px',
            color: 'rgba(255, 255, 255, 0.6)',
            textAlign: 'center',
            margin: 0
          }}>
            Distraction detected. Explain why.
          </p>
        )}

        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <AnimatePresence mode="wait">
            {isLoading ? (
              <motion.div
                key="loading"
                initial={{ opacity: 0 }}
                animate={{ opacity: 1 }}
                exit={{ opacity: 0 }}
                style={{ textAlign: 'center', display: 'flex', flexDirection: 'column', gap: '10px' }}
              >
                <div
                  style={{
                    width: '18px',
                    height: '18px',
                    border: '2px solid rgba(255, 255, 255, 0.3)',
                    borderTopColor: 'rgba(255, 255, 255, 0.9)',
                    borderRadius: '50%',
                    animation: 'spin 1s linear infinite',
                    margin: '0 auto'
                  }}
                />
                <p style={{ color: 'rgba(255, 255, 255, 0.7)', margin: 0, fontSize: '13px' }}>AI is thinking...</p>
              </motion.div>
            ) : showDurationSelection ? (
              <motion.div
                key="duration"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}
              >
                <p style={{
                  fontSize: '13px',
                  color: 'rgba(255, 255, 255, 0.7)',
                  textAlign: 'center',
                  margin: 0
                }}>
                  Choose duration:
                </p>
                {remainingAccessTime !== null && (
                  <p style={{
                    fontSize: '11px',
                    color: 'rgba(255, 255, 255, 0.5)',
                    textAlign: 'center',
                    margin: 0
                  }}>
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
                        borderRadius: '16px',
                        background: 'rgba(255, 255, 255, 0.22)',
                        border: 'none',
                        color: 'rgba(255, 255, 255, 0.9)',
                        cursor: 'pointer',
                        fontSize: '13px',
                        transition: 'background 0.2s ease'
                      }}
                    >
                      {label}
                    </button>
                  ))}
                </div>
              </motion.div>
            ) : aiResponse ? (
              <motion.div
                key="response"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                style={{ textAlign: 'center' }}
              >
                <TypingText text={aiResponse} />
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
                    borderRadius: '16px',
                    background: 'rgba(255, 255, 255, 0.22)',
                    border: 'none',
                    color: 'rgba(255, 255, 255, 0.9)',
                    cursor: 'pointer',
                    fontSize: '13px'
                  }}
                >
                  {showDeniedMessage ? 'Try Again' : 'Close'}
                </button>
              </motion.div>
            ) : showTakeoverView ? (
              <TakeoverView
                configuration={configuration}
                onDismiss={() => {
                  setShowTakeoverView(false);
                  onClose();
                  resetState();
                }}
              />
            ) : (
              <motion.div
                key="input"
                initial={{ opacity: 0, y: 10 }}
                animate={{ opacity: 1, y: 0 }}
                exit={{ opacity: 0, y: -10 }}
                style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}
              >
                <p style={{
                  fontSize: '13px',
                  fontWeight: '500',
                  color: 'rgba(255, 255, 255, 0.85)',
                  textAlign: 'center',
                  margin: 0
                }}>
                  Why do you need access?
                </p>
                <div style={{
                  display: 'flex',
                  alignItems: 'flex-end',
                  gap: '8px',
                  padding: '8px',
                  borderRadius: '18px',
                  background: 'rgba(255, 255, 255, 0.08)',
                  border: '1px solid rgba(255, 255, 255, 0.08)'
                }}>
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
                      border: isTextareaFocused ? '1px solid rgba(255, 255, 255, 0.4)' : 'none',
                      color: 'rgba(255, 255, 255, 0.9)',
                      fontSize: '13px',
                      resize: 'none',
                      outline: 'none',
                      minHeight: '48px',
                      padding: '8px 12px',
                      borderRadius: '14px',
                      transition: 'border 0.15s ease'
                    }}
                    spellCheck="false"
                  />
                  <button
                    onClick={handleSubmit}
                    disabled={!userInput.trim() || isLoading}
                    style={{
                      width: '32px',
                      height: '32px',
                      borderRadius: '50%',
                      background: userInput.trim()
                        ? 'rgba(255, 255, 255, 0.9)'
                        : 'rgba(255, 255, 255, 0.2)',
                      border: 'none',
                      color: userInput.trim() ? '#000' : 'rgba(255, 255, 255, 0.5)',
                      cursor: userInput.trim() ? 'pointer' : 'default',
                      fontSize: '14px',
                      flexShrink: 0
                    }}
                  >
                    ↑
                  </button>
                </div>
              </motion.div>
            )}
          </AnimatePresence>
        </div>

        <style>{`
          @keyframes spin {
            to { transform: rotate(360deg); }
          }
        `}</style>
      </motion.div>
    </AnimatePresence>
  );
};

interface TypingTextProps {
  text: string;
}

const TypingText: React.FC<TypingTextProps> = ({ text }) => {
  const [displayedText, setDisplayedText] = React.useState('');

  React.useEffect(() => {
    const words = text.split(' ');
    setDisplayedText('');
    let wordIndex = 0;
    
    const timer = setInterval(() => {
      if (wordIndex < words.length) {
        setDisplayedText(prev => {
          const newText = prev + (prev ? ' ' : '') + words[wordIndex];
          return newText;
        });
        wordIndex++;
      } else {
        clearInterval(timer);
      }
    }, 100);
    return () => clearInterval(timer);
  }, [text]);

  return (
    <p style={{
      fontSize: '13px',
      color: 'rgba(255, 255, 255, 0.85)',
      textAlign: 'center',
      lineHeight: 1.4
    }}>
      {displayedText}
    </p>
  );
};
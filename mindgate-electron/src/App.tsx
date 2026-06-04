import React, { useEffect, useState } from 'react';
import { Configuration, DecisionResult } from './types';
import { Orb } from './components/orb/Orb';
import { ChatInterface } from './components/chat/ChatInterface';
import { Overlay } from './components/overlay/Overlay';
import { WindowManager } from './services/windowManager';

const App: React.FC = () => {
  const [configuration, setConfiguration] = useState<Configuration | null>(null);
  const [isOrbExpanded, setIsOrbExpanded] = useState(false);
  const [isOverlayVisible, setIsOverlayVisible] = useState(false);
  const [windowManager] = useState(() => new WindowManager({} as Configuration));

  useEffect(() => {
    window.mindgateAPI.getConfiguration().then(setConfiguration);
  }, []);

  useEffect(() => {
    window.mindgateAPI.onShowOrb(() => {
      setIsOrbExpanded(true);
    });

    window.mindgateAPI.onHideOrb(() => {
      setIsOrbExpanded(false);
    });

    window.mindgateAPI.onShowOverlay(() => {
      setIsOverlayVisible(true);
    });

    window.mindgateAPI.onHideOverlay(() => {
      setIsOverlayVisible(false);
    });
  }, []);

  useEffect(() => {
    if (configuration) {
      windowManager.updateConfiguration(configuration);
    }
  }, [configuration]);

  const handleExpand = () => {
    setIsOrbExpanded(true);
  };

  const handleClose = () => {
    setIsOrbExpanded(false);
    window.mindgateAPI.hideOrb();
  };

  const handleSubmit = async (userInput: string): Promise<DecisionResult | void> => {
    const result = await window.mindgateAPI.evaluateRequest(userInput);
    if (!result.isApproved) {
      window.mindgateAPI.closeDistraction();
    }
    return result;
  };

  if (!configuration) {
    return <div>Loading...</div>;
  }

  return (
    <>
      {isOrbExpanded ? (
        <ChatInterface
          configuration={configuration}
          onSubmit={handleSubmit}
          onClose={handleClose}
        />
      ) : (
        <Orb configuration={configuration} onExpand={handleExpand} />
      )}
      <Overlay visible={isOverlayVisible} />
    </>
  );
};

export default App;
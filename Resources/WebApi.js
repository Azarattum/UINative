window.UINative = {
  feedback: (type) => {
    window.webkit.messageHandlers.feedback.postMessage(`${type}`);
  },
};

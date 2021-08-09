window.UINative = {
  feedback: (type) => {
    window.webkit.messageHandlers.feedback.postMessage(`${type}`);
  },

  nativeAudio: () => {
    {
      window.webkit.messageHandlers.audio.postMessage({
        action: "enable",
      });
      window.Audio = NativeAudio;
    }
  },
};

class NativeAudio extends Audio {
  constructor(src) {
    super();
    this.preload = "none";
    const id = Math.random().toString(36);
    this.use = (action, data) =>
      window.webkit.messageHandlers.audio.postMessage({
        id,
        action,
        data,
      });

    this.play = () => {
      this.use("play");
    };

    Object.defineProperty(this, "src", {
      set(value) {
        this.use("setSource", value);
      },
    });

    Object.defineProperty(this, "metadata", {
      set(value) {
        this.use("setMetadata", value);
      },
    });

    if (src) this.src = src;
  }
}

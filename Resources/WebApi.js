window.UINative = {
  feedback: (type) => {
    window.webkit.messageHandlers.feedback.postMessage(`${type}`);
  },

  nativeAudio: () => {
    {
      document.createEvent("Event").initEvent("aduioCallback", false, false);
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

    this.pause = () => {
      this.use("pause");
    };

    this.fastSeek = (value) => {
      this.use("seek", value);
    };

    Object.defineProperty(this, "currentTime", {
      set(value) {
        this.use("seek", value);
      },
    });

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

    Object.defineProperty(this, "preload", {
      set() {},
    });

    document.addEventListener("aduioCallback", (event) => {
      if (id === event.id && event.action) {
        let action = event.action;
        if (action.startsWith("on")) {
          action = action.substr(2).toLowerCase();
          this.dispatchEvent(new Event(action));
        }
      }
    });

    if (src) this.src = src;
  }
}

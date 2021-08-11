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

    this._playbackRate = 0.0;
    this._currentTime = 0.0;
    this._duration = NaN;
    this._src = "";
    this._metadata = {};

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
      get() {
        if (this._currentTime < 0) return 0;
        return this._currentTime;
      },
    });

    Object.defineProperty(this, "playbackRate", {
      set(value) {
        this.use("setRate", value);
      },
      get() {
        return this._playbackRate;
      },
    });

    Object.defineProperty(this, "src", {
      set(value) {
        this.use("setSource", value);
        this._src = value;
      },
      get() {
        return this._src;
      },
    });

    Object.defineProperty(this, "metadata", {
      set(value) {
        this.use("setMetadata", value);
        this._metadata = value;
      },
      get() {
        return this._metadata;
      },
    });

    Object.defineProperty(this, "duration", {
      get() {
        return this._duration;
      },
    });

    Object.defineProperty(this, "preload", {
      set() {},
      get() {
        return "auto";
      },
    });

    document.addEventListener("aduioCallback", (event) => {
      if (id === event.id && event.action) {
        if (event.rate != null) this._playbackRate = event.rate;
        if (event.time != null) this._currentTime = event.time;
        if (event.duration != null) this._duration = event.duration;

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

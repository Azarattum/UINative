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

    this._preload = "metadata";
    this._playbackRate = 0.0;
    this._currentTime = 0.0;
    this._destroyed = false;
    this._duration = NaN;
    this._metadata = {};
    this._volume = NaN;
    this._muted = 0;
    this._src = "";

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

    Object.defineProperty(this, "volume", {
      set(value) {
        this.use("setVolume", value);
      },
      get() {
        return this._volume;
      },
    });

    Object.defineProperty(this, "muted", {
      set(value) {
        if (value) {
          if (this._volume) {
            this._muted = this._volume;
            this.use("setVolume", 0);
          }
        } else {
          if (this._muted) {
            this.use("setVolume", this._muted);
            this._muted = 0;
          }
        }
      },
      get() {
        return !!this._muted;
      },
    });

    Object.defineProperty(this, "src", {
      set(value) {
        this._destroyed = false;
        this.use("setSource", value);
        this._src = value;
        if (this._preload == "auto") this.use("load");
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
      set(value) {
        if (value === "" || value === "auto") {
          if (this._src) this.use("load");
          this._preload = "auto";
        }
      },
      get() {
        return this._preload;
      },
    });

    Object.defineProperty(this, "destroyed", {
      set(value) {
        if (value) {
          this._playbackRate = 0.0;
          this._currentTime = 0.0;
          this._destroyed = true;
          this._duration = NaN;
          this._metadata = {};
          this._volume = NaN;
          this._muted = 0;
          this._src = "";
          this.use("destroy");
        }
      },
      get() {
        return this._destroyed;
      },
    });

    document.addEventListener("aduioCallback", (event) => {
      if (id === event.id && event.action) {
        if (event.duration != null) this._duration = event.duration;
        if (event.rate != null) this._playbackRate = event.rate;
        if (event.time != null) this._currentTime = event.time;
        if (event.volume != null) this._volume = event.volume;
        if (this._muted && this._volume) this._muted = 0;

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

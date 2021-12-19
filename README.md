# UI Native
Jailbreak tweak to bring some native iOS APIs to web.

## Curretly Supported APIs:
### Feedback
  
- Usage: `UINative.feedback(<type>)`
- Types: `selection`, `light`, `medium`, `heavy`, `rigid`, `soft`, `success`, `warning`, `error`
- Example:
```JavaScript
if (window.UINative) {
    UINative.feedback("selection");
}
```

### Native Audio (with metadata)

- Enable: `UINative.nativeAudio()`
- Supported methods: `play`, `pause`, `fastSeek`
- Supported properties: `currentTime`, `playbackRate`, `volume`, `muted`, `src`, `duration`, `preload`, `paused`, `ended`
- Supported callbacks: `onplay`, `onplaying`, `onpause`, `onended`, `onseeking`, `onseeked`, `onloadeddata`, `onloadedmetadata`, `oncanplaythrough`, `ontimeupdate`, `onratechange`, `ondurationchange`, `onvolumechange`
- New properties: `metadata`, `destroyed`
- Example:
```JavaScript
if (window.UINative) {
    UINative.nativeAudio();
}

const audio = new Audio("http://example.com/audio.mp3");
audio.preload = "auto";
audio.metadata = {
    title: "A Song",
    artist: "Somebody",
    album: "Single",
    year: 2042,
    length: 42,
    cover: "http://example.com/cover.jpg"
};
audio.play();
audio.onended = () => {
    audio.destroyed = true;
};
```
Note that you need to set `audio.destroyed = true` when you are done with the audio object to avoid memory leaks!

## Building:
This tweak is built with [orion](https://github.com/theos/orion) via [theos](https://github.com/theos/theos).

You need to have these environment variables set (change `<DEVICE IP>`):
```sh
#!/bin/sh

export THEOS=/opt/theos
export PATH=$THEOS/bin:$PATH
export THEOS_DEVICE_IP=<DEVICE IP>
export THEOS_DEVICE_PORT=22
```

Build and deploy the package to your phone:
```sh
make do
```
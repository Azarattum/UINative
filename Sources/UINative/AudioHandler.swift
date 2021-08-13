import WebKit

class AudioHandler: NSObject, WKScriptMessageHandler {
  ///Not clearing audios might cause a memory leak!
  var audios: [String: Audio] = Dictionary()

  func userContentController(
    _ userContentController: WKUserContentController, didReceive message: WKScriptMessage
  ) {
    if message.name != "audio" { return }
    if let info = message.body as? NSDictionary {
      switch info["action"] as? String {
      case "enable":
        self.enable()
        break
      case "setSource":
        guard let id = info["id"] as? String else { break }
        guard let data = info["data"] as? String else { break }
        guard let web = message.webView else { break }
        self.setSource(id: id, source: data, web: web)
        break
      case "setMetadata":
        guard let id = info["id"] as? String else { break }
        guard let data = info["data"] as? [String: Any] else { break }
        self.setMetadata(id: id, data: data)
        break
      case "setRate":
        guard let id = info["id"] as? String else { break }
        guard let data = info["data"] as? Double else { break }
        self.setRate(id: id, value: Float(data))
        break
      case "setVolume":
        guard let id = info["id"] as? String else { break }
        guard let data = info["data"] as? Double else { break }
        self.setVolume(id: id, value: Float(data))
        break
      case "load":
        guard let id = info["id"] as? String else { break }
        self.load(id: id)
        break
      case "play":
        guard let id = info["id"] as? String else { break }
        self.play(id: id)
        break
      case "pause":
        guard let id = info["id"] as? String else { break }
        self.pause(id: id)
        break
      case "seek":
        guard let id = info["id"] as? String else { break }
        guard let data = info["data"] as? Double else { break }
        self.seek(id: id, to: data)
        break
      default:
        break
      }
    }
  }

  func enable() {
    Audio.setupSession()
    Audio.setupControls()
  }

  func setSource(id: String, source: String, web: WKWebView) {
    if let item = audios[id] {
      item.setSource(source: source)
      return
    }
    self.audios[id] = Audio(source: source)

    let handle: (Notification) -> Void = { notification in
      var action = notification.name.rawValue
      action = action.replacingOccurrences(of: "AudioEvent", with: "on")
      let info = notification.userInfo

      if action == "onSeeked" {
        self.callback(web, id: id, action: "onSeeking", info: info)
      }

      self.callback(web, id: id, action: action, info: info)

      if action == "onPlay" {
        self.callback(web, id: id, action: "onPlaying", info: info)
      }
    }

    let observe: (Notification.Name) -> Void = { name in
      NotificationCenter.default.addObserver(
        forName: name, object: self.audios[id], queue: OperationQueue.main,
        using: handle
      )
    }

    observe(AudioEvent.Play)
    observe(AudioEvent.Pause)
    observe(AudioEvent.Ended)
    observe(AudioEvent.Seeked)
    observe(AudioEvent.Stalled)
    observe(AudioEvent.Meta)
    observe(AudioEvent.Loaded)
    observe(AudioEvent.Time)
    observe(AudioEvent.Rate)
    observe(AudioEvent.Duration)
    observe(AudioEvent.CanPlay)
    observe(AudioEvent.CanPlayThrough)
    observe(AudioEvent.Volume)
  }

  func setMetadata(id: String, data: [String: Any]) {
    if let item = self.audios[id] {
      item.setMetadata(metadata: Metadata(dictionary: data))
    }
  }

  func load(id: String) {
    if let item = audios[id] {
      item.load()
      return
    }
  }

  func play(id: String) {
    if let item = audios[id] {
      item.play()
      return
    }
  }

  func pause(id: String) {
    if let item = audios[id] {
      item.pause()
      return
    }
  }

  func seek(id: String, to: Double) {
    if let item = audios[id] {
      item.seek(to: to)
    }
  }

  func setRate(id: String, value: Float) {
    if let item = audios[id] {
      item.setRate(to: value)
    }
  }

  func setVolume(id: String, value: Float) {
    if let item = audios[id] {
      item.setVolume(to: value)
    }
  }

  func callback(_ web: WKWebView, id: String, action: String, info: [AnyHashable: Any]?) {
    let template = """
      document.dispatchEvent(
        Object.assign(new Event("aduioCallback"), {
          id: "%@",
          action: "%@",
        }, %@)
      );
      """

    var jsonInfo: String = "{}"
    do {
      let data = try JSONSerialization.data(
        withJSONObject: info ?? [AnyHashable: Any](), options: []
      )
      if let json = String(data: data, encoding: .utf8) {
        jsonInfo = json
      }
    } catch {}

    let code = String(format: template, id, action, jsonInfo)
    web.evaluateJavaScript(code)
  }
}

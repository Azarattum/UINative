import Foundation
import MediaPlayer
import UINativeC

class Audio: NSObject {
  static var current: Audio? = nil

  private var player: AVPlayer = AVPlayer()
  private var metadata: [String: Any] = [String: Any]()

  private var timeObserver: Any?

  private var isCurrent: Bool {
    return Audio.current == self
  }

  init(source: String) {
    super.init()
    self.setSource(source: source)

    NotificationCenter.default.addObserver(
      self, selector: #selector(onNotification),
      name: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
      object: nil
    )
  }

  func registerObservers() {
    player.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
    player.currentItem?.addObserver(
      self, forKeyPath: "playbackLikelyToKeepUp", options: [.initial], context: nil)

    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTimeMake(value: 1, timescale: 3), queue: DispatchQueue.main
    ) { (CMTime) -> Void in
      if self.player.currentItem?.status == .readyToPlay && self.player.rate != 0.0 {
        self.updatePlayback()
      }
    }

    let center = NotificationCenter.default

    center.addObserver(
      self, selector: #selector(onNotification), name: .AVPlayerItemDidPlayToEndTime,
      object: player.currentItem
    )
    center.addObserver(
      self, selector: #selector(onNotification), name: .AVPlayerItemPlaybackStalled,
      object: player.currentItem
    )
    center.addObserver(
      self, selector: #selector(onNotification), name: .AVPlayerItemTimeJumped,
      object: player.currentItem
    )
  }

  func removeObservers() {
    let center = NotificationCenter.default
    center.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    center.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: player.currentItem)
    center.removeObserver(self, name: .AVPlayerItemTimeJumped, object: player.currentItem)

    player.removeObserver(self, forKeyPath: "rate")
    if let observer = timeObserver {
      player.removeTimeObserver(observer)
    }
  }

  @objc func onNotification(_ notification: Notification) {
    let center = NotificationCenter.default

    switch notification.name {
    case .AVPlayerItemDidPlayToEndTime:
      center.post(name: AudioEvent.Ended, object: self)
      break
    case .AVPlayerItemTimeJumped:
      center.post(name: AudioEvent.Seeked, object: self)
      break
    case .AVPlayerItemPlaybackStalled:
      center.post(name: AudioEvent.Stalled, object: self)
      break
    case NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"):
      center.post(
        name: AudioEvent.Volume, object: self,
        userInfo: ["volume": VolumeController.getVolume()]
      )
      break
    default:
      break
    }
  }

  override func observeValue(
    forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?,
    context: UnsafeMutableRawPointer?
  ) {
    if keyPath == "rate", let player = object as? AVPlayer {
      guard let newValue = change?[.newKey] as? Float, let oldValue = change?[.oldKey] as? Float,
        newValue != oldValue
      else { return }

      let center = NotificationCenter.default

      if player.rate == 0.0 {
        center.post(name: AudioEvent.Pause, object: self)
      } else {
        center.post(name: AudioEvent.Play, object: self)
      }
      updatePlayback()
    }

    if keyPath == "playbackLikelyToKeepUp" && object is AVPlayerItem {
      NotificationCenter.default.post(name: AudioEvent.CanPlayThrough, object: self)
    }
  }

  func play() {
    if !isCurrent {
      Audio.current?.stop()
      Audio.current = self
      registerObservers()
      updateMetadata()
    }

    player.play()
  }

  func pause() {
    player.pause()
  }

  func stop() {
    removeObservers()
    pause()
    seek(to: .zero)

    timeObserver = nil
  }

  func seek(to: Double) {
    seek(to: CMTime(seconds: to, preferredTimescale: 1))
  }

  func seek(to: CMTime) {
    player.seek(to: to) { _ in
      self.updatePlayback()
    }
  }

  func setVolume(to: Float) {
    VolumeController.setVolume(to)
  }

  func setRate(to: Float) {
    if to != 0.0 && !isCurrent {
      play()
    }

    player.rate = to
  }

  func setSource(source: String) {
    let url = URL.init(string: source)
    let item = AVPlayerItem(url: url!)

    //Update duration when asset loads
    var observation: Any? = nil
    observation = item.observe(
      \AVPlayerItem.status,
      options: [.initial, .new],
      changeHandler: { observedItem, change in
        //Check when ready
        if observedItem.status == AVPlayerItem.Status.readyToPlay {
          let duration = observedItem.duration.seconds
          self.metadata[MPMediaItemPropertyPlaybackDuration] = duration

          let center = NotificationCenter.default
          center.post(name: AudioEvent.Meta, object: self)
          center.post(
            name: AudioEvent.Duration, object: self,
            userInfo: ["duration": duration]
          )

          if self.isCurrent {
            self.updateMetadata()
            self.updatePlayback()
          }
          if observation != nil {
            observation = nil
          }

          center.post(name: AudioEvent.Loaded, object: self)
          center.post(name: AudioEvent.CanPlay, object: self)
          center.post(
            name: AudioEvent.Volume, object: self,
            userInfo: ["volume": VolumeController.getVolume()]
          )
        }
      })

    //This preloads the item
    player.replaceCurrentItem(with: item)
  }

  func setMetadata(metadata: Metadata) {
    self.metadata[MPMediaItemPropertyTitle] = metadata.title
    self.metadata[MPMediaItemPropertyArtist] = metadata.artist
    if metadata.album != nil {
      self.metadata[MPMediaItemPropertyAlbumTitle] = metadata.album
    }
    if metadata.year != nil {
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy"
      let date = formatter.date(from: String(metadata.year!))
      self.metadata[MPMediaItemPropertyReleaseDate] = date
    }
    if metadata.length != nil && self.metadata[MPMediaItemPropertyPlaybackDuration] == nil {
      self.metadata[MPMediaItemPropertyPlaybackDuration] = metadata.length
    }

    //Load cover image
    if metadata.cover != nil {
      if let url = URL(string: metadata.cover!) {
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
          guard let data = data else { return }

          if let albumArt = UIImage(data: data) {
            self.metadata[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
              boundsSize: albumArt.size,
              requestHandler: { imageSize in
                return albumArt
              })

            if self.isCurrent {
              self.updateMetadata()
            }
          }
        }
        task.resume()
      }
    }
  }

  private func updateMetadata() {
    if !isCurrent { return }
    if self.metadata.isEmpty { return }

    let infoCenter = MPNowPlayingInfoCenter.default()
    infoCenter.nowPlayingInfo = self.metadata
  }

  private func updatePlayback() {
    if !isCurrent { return }

    let infoCenter = MPNowPlayingInfoCenter.default()
    var info = infoCenter.nowPlayingInfo ?? [String: Any]()

    info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

    let center = NotificationCenter.default
    center.post(
      name: AudioEvent.Rate, object: self,
      userInfo: ["rate": player.rate]
    )

    if let item = player.currentItem {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = item.currentTime().seconds

      center.post(
        name: AudioEvent.Time, object: self,
        userInfo: ["time": item.currentTime().seconds]
      )
    }

    infoCenter.nowPlayingInfo = info
  }

  static func setupSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: AVAudioSession.Mode.default
      )
    } catch {}
  }

  static func setupControls() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }

      if audio.player.rate == 0.0 {
        audio.player.play()
        return .success
      }

      return .commandFailed
    }

    commandCenter.pauseCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }

      if audio.player.rate == 0.0 {
        return .commandFailed
      }

      audio.player.pause()
      return .success
    }

    commandCenter.changePlaybackPositionCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }

      let time = (event as! MPChangePlaybackPositionCommandEvent).positionTime
      audio.seek(to: time)
      return .success
    }

    commandCenter.seekForwardCommand.addTarget { [self] event in
      guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }

      audio.player.rate = (event.type == .beginSeeking ? 3.0 : 1.0)
      return .success
    }

    commandCenter.seekBackwardCommand.addTarget { [self] event in
      guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }

      audio.player.rate = (event.type == .beginSeeking ? -3.0 : 1.0)
      return .success
    }

    commandCenter.nextTrackCommand.addTarget { [self] event in
      if let item = current?.player.currentItem {
        current!.seek(to: item.duration.seconds)
        return .success
      }
      return .commandFailed
    }

    commandCenter.previousTrackCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }
      audio.seek(to: .zero)
      return .success
    }

    commandCenter.skipForwardCommand.isEnabled = false
    commandCenter.skipForwardCommand.addTarget { [self] event in
      guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }
      audio.seek(
        to: audio.player.currentTime() + CMTime(seconds: event.interval, preferredTimescale: 1))
      return .success
    }

    commandCenter.skipBackwardCommand.isEnabled = false
    commandCenter.skipBackwardCommand.addTarget { [self] event in
      guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }
      audio.seek(
        to: audio.player.currentTime() - CMTime(seconds: event.interval, preferredTimescale: 1))
      return .success
    }
  }
}

struct AudioEvent {
  static let Pause = Notification.Name("AudioEventPause")
  static let Play = Notification.Name("AudioEventPlay")
  static let Ended = Notification.Name("AudioEventEnded")
  static let Seeked = Notification.Name("AudioEventSeeked")
  static let Stalled = Notification.Name("AudioEventStalled")
  static let Meta = Notification.Name("AudioEventLoadedMetaData")
  static let Loaded = Notification.Name("AudioEventLoadedData")
  static let Time = Notification.Name("AudioEventTimeUpdate")
  static let Rate = Notification.Name("AudioEventRateChange")
  static let Duration = Notification.Name("AudioEventDurationChange")
  static let CanPlay = Notification.Name("AudioEventCanPlay")
  static let CanPlayThrough = Notification.Name("AudioEventCanPlayThrough")
  static let Volume = Notification.Name("AudioEventVolumeChange")
}

struct Metadata {
  let title: String
  let artist: String

  let album: String?
  let year: Int?
  let cover: String?
  let length: Float?

  init(dictionary: [String: Any]) {
    self.title = dictionary["title"] as? String ?? "Untitled"
    self.artist = dictionary["artist"] as? String ?? "Unknown"

    self.album = dictionary["album"] as? String ?? nil
    self.year = dictionary["year"] as? Int ?? nil
    self.cover = dictionary["cover"] as? String ?? nil
    self.length = dictionary["length"] as? Float ?? nil
  }
}

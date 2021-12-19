import Foundation
import MediaPlayer
import UINativeC

class Audio: NSObject {
  static var current: Audio? = nil
  static var controlTargets: [String: Any] = [String: Any]()
  static var interceptionObserver: Any?

  private var item: AVPlayerItem!
  private var player: AVPlayer = AVPlayer()
  private var metadata: [String: Any] = [String: Any]()

  private var timeObserver: Any?

  private var isObserved = false;
  private var isCurrent: Bool {
    return Audio.current == self
  }

  init(source: String) {
    super.init()
    player.automaticallyWaitsToMinimizeStalling = false;
    self.setSource(source: source)
  }

  func registerObservers() {
    if self.isObserved { return; }

    player.addObserver(self, forKeyPath: "rate", options: [.new, .old], context: nil)
    player.currentItem?.addObserver(
      self, forKeyPath: "playbackLikelyToKeepUp", options: [.initial], context: nil)

    timeObserver = player.addPeriodicTimeObserver(
      forInterval: CMTimeMake(value: 1, timescale: 3), queue: DispatchQueue.main
    ) { [weak self] (CMTime) -> Void in
      if self == nil || !self!.isCurrent { return }
      if self!.player.currentItem?.status == .readyToPlay && self!.player.rate != 0.0 {
        self!.updatePlayback()
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
      self, selector: #selector(onNotification), name: AVPlayerItem.timeJumpedNotification,
      object: player.currentItem
    )

    self.isObserved = true;
  }

  func removeObservers() {
    guard self.isObserved else { return; }
    let center = NotificationCenter.default
    center.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
    center.removeObserver(self, name: .AVPlayerItemPlaybackStalled, object: player.currentItem)
    center.removeObserver(self, name: AVPlayerItem.timeJumpedNotification, object: player.currentItem)

    player.removeObserver(self, forKeyPath: "rate")
    player.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp")
    if let observer = timeObserver {
      player.removeTimeObserver(observer)
    }
    self.isObserved = false;
  }

  @objc func onNotification(_ notification: Notification) {
    let center = NotificationCenter.default

    switch notification.name {
    case .AVPlayerItemDidPlayToEndTime:
      center.post(name: AudioEvent.Ended, object: self)
      break
    case AVPlayerItem.timeJumpedNotification:
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

      center.post(name: AudioEvent.Rate, object: self, userInfo: ["rate": player.rate])
      if player.rate == 0.0 {
        center.post(name: AudioEvent.Pause, object: self)
      } else {
        center.post(name: AudioEvent.Play, object: self)
      }

      updatePlayback()
    }

    if keyPath == "playbackLikelyToKeepUp", let item = object as? AVPlayerItem {
      if item.isPlaybackLikelyToKeepUp {
        NotificationCenter.default.post(name: AudioEvent.CanPlayThrough, object: self)
      }
    }
  }

  func play() {
    if player.currentItem == nil {
      load()
    }
    if !isCurrent {
      if Audio.current == nil {
        Audio.setupControls()
      } else {
        Audio.current!.stop()
      }

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
    player.seek(to: to) { [weak self] _ in
      if self != nil && self!.isCurrent {
        self!.updatePlayback()
      }
    }
  }

  func load() {
    //This starts track loading
    player.replaceCurrentItem(with: item)
  }

  func destroy() {
    NotificationCenter.default.removeObserver(
      self, name: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
      object: nil
    )
    if isCurrent {
      Audio.current = nil
      Audio.removeControls()
      MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    stop()
    item = nil
    metadata = [String: Any]()
    player.replaceCurrentItem(with: nil)
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
    let center = NotificationCenter.default

    center.removeObserver(
      self, name: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
      object: nil
    )
    center.addObserver(
      self, selector: #selector(onNotification),
      name: Notification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
      object: nil
    )

    let url = URL.init(string: source)
    let item = AVPlayerItem(url: url!)
    item.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
      let status = item.asset.statusOfValue(forKey: "duration", error: nil)
      if status != .loaded { return }

      let duration = item.asset.duration.seconds
      self.metadata[MPMediaItemPropertyPlaybackDuration] = duration
      center.post(name: AudioEvent.Meta, object: self)
      center.post(
        name: AudioEvent.Duration, object: self,
        userInfo: ["duration": duration]
      )
      center.post(
        name: AudioEvent.Volume, object: self,
        userInfo: ["volume": VolumeController.getVolume()]
      )
    }

    //Check load status when asset loads
    var observation: Any? = nil
    observation = item.observe(
      \AVPlayerItem.status,
      options: [.initial, .new],
      changeHandler: { [weak self] observedItem, change in
        guard self != nil else { return }
        //Check when ready
        if observedItem.status == AVPlayerItem.Status.readyToPlay {
          if self!.isCurrent {
            self!.updateMetadata()
            self!.updatePlayback()
          }
          center.post(name: AudioEvent.Loaded, object: self)
          center.post(name: AudioEvent.CanPlay, object: self)

          if observation != nil {
            observation = nil
          }
        }
      })

    //Set the item
    self.item = item
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
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
          guard let data = data else { return }

          if let albumArt = UIImage(data: data) {
            guard self != nil else { return }
            self!.metadata[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(
              boundsSize: albumArt.size,
              requestHandler: { imageSize in
                return albumArt
              })

            if self!.isCurrent {
              self!.updateMetadata()
            }
          }
        }
        task.resume()
      }
    }
  }

  private func updateMetadata() {
    if !isCurrent { return }

    let infoCenter = MPNowPlayingInfoCenter.default()
    infoCenter.nowPlayingInfo = self.metadata
  }

  private func updatePlayback() {
    if !isCurrent { return }

    let infoCenter = MPNowPlayingInfoCenter.default()
    var info = infoCenter.nowPlayingInfo ?? [String: Any]()

    info[MPNowPlayingInfoPropertyPlaybackRate] = player.rate

    let center = NotificationCenter.default
    if let item = player.currentItem {
      info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = item.currentTime().seconds

      center.post(
        name: AudioEvent.Time, object: self,
        userInfo: ["time": item.currentTime().seconds]
      )
    }

    if !isCurrent { return }
    infoCenter.nowPlayingInfo = info
  }

  static func setupSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: .default
      )
      if let observer = self.interceptionObserver {
        NotificationCenter.default.removeObserver(observer);
      }
      self.interceptionObserver = NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification, object: nil, queue: OperationQueue.main,
        using: { [self] notification in
          guard let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
          }
          
          switch type {
          case .ended:
            guard let audio = self.current else { return }
            audio.player.play()
          default: break
          }
      })
    } catch {}
  }

  static func closeSession() {
    if let observer = self.interceptionObserver {
      NotificationCenter.default.removeObserver(observer);
    }
    do {
      try AVAudioSession.sharedInstance().setActive(false) 
    } catch {}
  }

  static func setupControls() {
    removeControls()

    let commandCenter = MPRemoteCommandCenter.shared()

    controlTargets["play"] = commandCenter.playCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }

      if audio.player.rate == 0.0 {
        audio.player.play()
        return .success
      }

      return .commandFailed
    }

    controlTargets["pause"] = commandCenter.pauseCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }

      if audio.player.rate == 0.0 {
        return .commandFailed
      }

      audio.player.pause()
      return .success
    }

    controlTargets["changePlaybackPosition"] = commandCenter.changePlaybackPositionCommand.addTarget
    {
      [self] event in
      guard let audio = current else { return .commandFailed }

      let time = (event as! MPChangePlaybackPositionCommandEvent).positionTime
      audio.seek(to: time)
      return .success
    }

    controlTargets["seekForward"] = commandCenter.seekForwardCommand.addTarget { [self] event in
      guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }

      audio.player.rate = (event.type == .beginSeeking ? 3.0 : 1.0)
      return .success
    }

    controlTargets["seekBackward"] = commandCenter.seekBackwardCommand.addTarget { [self] event in
      guard let event = event as? MPSeekCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }

      audio.player.rate = (event.type == .beginSeeking ? -3.0 : 1.0)
      return .success
    }

    controlTargets["nextTrack"] = commandCenter.nextTrackCommand.addTarget { [self] event in
      if let item = current?.player.currentItem {
        current!.seek(to: item.duration.seconds)
        return .success
      }
      return .commandFailed
    }

    controlTargets["previousTrack"] = commandCenter.previousTrackCommand.addTarget { [self] event in
      guard let audio = current else { return .commandFailed }
      audio.seek(to: .zero)
      return .success
    }

    commandCenter.skipForwardCommand.isEnabled = false
    controlTargets["skipForward"] = commandCenter.skipForwardCommand.addTarget { [self] event in
      guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }
      audio.seek(
        to: audio.player.currentTime() + CMTime(seconds: event.interval, preferredTimescale: 1))
      return .success
    }

    commandCenter.skipBackwardCommand.isEnabled = false
    controlTargets["skipBackward"] = commandCenter.skipBackwardCommand.addTarget { [self] event in
      guard let event = event as? MPSkipIntervalCommandEvent else { return .commandFailed }
      guard let audio = current else { return .commandFailed }
      audio.seek(
        to: audio.player.currentTime() - CMTime(seconds: event.interval, preferredTimescale: 1))
      return .success
    }
  }

  static func removeControls() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.pauseCommand.removeTarget(controlTargets["pause"])
    commandCenter.playCommand.removeTarget(controlTargets["play"])
    commandCenter.seekForwardCommand.removeTarget(controlTargets["seekForward"])
    commandCenter.seekBackwardCommand.removeTarget(controlTargets["seekBackward"])
    commandCenter.nextTrackCommand.removeTarget(controlTargets["nextTrack"])
    commandCenter.previousTrackCommand.removeTarget(controlTargets["previousTrack"])
    commandCenter.skipForwardCommand.removeTarget(controlTargets["skipForward"])
    commandCenter.skipBackwardCommand.removeTarget(controlTargets["skipBackward"])
    commandCenter.changePlaybackPositionCommand.removeTarget(
      controlTargets["changePlaybackPosition"])
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

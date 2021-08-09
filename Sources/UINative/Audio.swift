import Foundation
import MediaPlayer

class Audio {
  static let player: AVPlayer = AVPlayer()

  private var item: AVPlayerItem?
  private var metadata: [String: Any] = [String: Any]()
  static private var rateObserver: NSKeyValueObservation!
  static private var statusObserver: NSObjectProtocol!

  init(source: String) {
    self.setSource(source: source)
  }

  func play() {
    if Audio.player.currentItem != self.item {
      Audio.player.replaceCurrentItem(with: self.item)
      self.updateMetadata()
    }
    Audio.player.play()
  }

  func pause() {
    if Audio.player.currentItem == self.item {
      Audio.player.pause()
    }
  }

  func setSource(source: String) {
    ///Consider async loading
    let url = URL.init(string: source)
    self.item = AVPlayerItem(url: url!)

    //Update duration when asset loads
    var observation: Any? = nil
    observation = self.item!.observe(
      \AVPlayerItem.status,
      changeHandler: { observedItem, change in
        //Check when ready
        if observedItem.status == AVPlayerItem.Status.readyToPlay {
          self.metadata[MPMediaItemPropertyPlaybackDuration] =
            observedItem.duration.seconds
          if Audio.player.currentItem == self.item {
            self.updateMetadata()
          }
          if observation != nil {
            observation = nil
          }
        }
      })
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

            if Audio.player.currentItem == self.item {
              self.updateMetadata()
            }
          }
        }
        task.resume()
      }
    }
  }

  private func updateMetadata() {
    if self.metadata.isEmpty { return }

    let infoCenter = MPNowPlayingInfoCenter.default()
    infoCenter.nowPlayingInfo = self.metadata
  }

  static func updatePlayback() {
    let infoCenter = MPNowPlayingInfoCenter.default()
    var info = infoCenter.nowPlayingInfo ?? [String: Any]()

    info[MPNowPlayingInfoPropertyPlaybackRate] = Audio.player.rate
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] =
      Audio.player.currentItem?.currentTime().seconds ?? 0

    infoCenter.nowPlayingInfo = info
  }

  static func setupSession() {
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .playback, mode: AVAudioSession.Mode.default
      )

      try AVAudioSession.sharedInstance().setActive(true)
    } catch {}
  }

  static func setupControls() {
    let commandCenter = MPRemoteCommandCenter.shared()

    commandCenter.playCommand.addTarget { [self] event in
      if self.player.rate == 0.0 {
        self.player.play()
        return .success
      }
      return .commandFailed
    }

    commandCenter.pauseCommand.addTarget { [self] event in
      if self.player.rate == 0.0 {
        return .commandFailed
      }

      self.player.pause()
      return .success
    }

    commandCenter.changePlaybackPositionCommand.addTarget { [self] event in
      let time = (event as! MPChangePlaybackPositionCommandEvent).positionTime
      player.seek(to: CMTime(seconds: time, preferredTimescale: 1)) {
        isFinished in
        if isFinished { self.updatePlayback() }
      }

      return .success
    }

    rateObserver = player.observe(\.rate, options: .initial) {
      [self] _, _ in
      self.updatePlayback()
    }

    statusObserver = player.observe(\.currentItem?.status, options: .initial) {
      [self] _, _ in
      self.updatePlayback()
    }
  }
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

import CoreMedia
import MPEGTransport

extension MediaTimestamp {
  public var cmTime: CMTime {
    return CMTime(value: value, timescale: scale)
  }

  public init(cmTime: CMTime) {
    self.init(value: cmTime.value, scale: cmTime.timescale)
  }
}

extension Date {
  public var videoTimestamp: MediaTimestamp {    
    MediaTimestamp(
      value: Int64(self.timeIntervalSince1970 * Double(MediaTimeScale.video)),
      scale: MediaTimeScale.video
    )
  }

  public var audioTimestamp: MediaTimestamp {
    MediaTimestamp(
      value: Int64(self.timeIntervalSince1970 * Double(MediaTimeScale.audio)),
      scale: MediaTimeScale.audio
    )
  }
}

extension CMTime {
  public var videoTimestamp: MediaTimestamp {
    MediaTimestamp(
      cmTime: convertScale(
        MediaTimeScale.video,
        method: .quickTime
      )
    )
  }

  public var audioTimestamp: MediaTimestamp {
    MediaTimestamp(
      cmTime: convertScale(
        MediaTimeScale.audio,
        method: .quickTime
      )
    )
  }
}

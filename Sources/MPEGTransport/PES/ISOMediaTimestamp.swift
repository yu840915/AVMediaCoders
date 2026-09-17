import LogContext

public struct ISOMediaTimestamp: Equatable, Sendable, LogContextReadable {
  let prefix: Prefix
  let value: UInt64

  public var logContext: LogContext {
    LogContext {
      $0["prefix"] = prefix
      $0["value"] = value
    }
  }

  public init(prefix: Prefix, truncating: UInt64) {
    self.prefix = prefix
    value = truncating & 0x1_FFFF_FFFF
  }

  public init(bytes: [UInt8]) throws {
    guard bytes.count >= 5 else {
      throw MPEGTransportError.bufferTooShort
    }
    try self.init(
      part1: bytes[0],
      part2: bytes[1],
      part3: bytes[2],
      part4: bytes[3],
      part5: bytes[4]
    )
  }

  init(part1: UInt8, part2: UInt8, part3: UInt8, part4: UInt8, part5: UInt8) throws {
    guard let prefix = Prefix(rawValue: part1 >> 4) else {
      throw MPEGTransportError.invalidISOTimestampPrefix
    }
    self.prefix = prefix
    value =
      (UInt64(part1) & 0b1110) << 29
      | UInt64(part2) << 22
      | (UInt64(part3) >> 1) << 15
      | UInt64(part4) << 7
      | UInt64(part5) >> 1
  }

  var bytes: [UInt8] {
    let part1 = UInt8(prefix.rawValue << 4 | UInt8(truncatingIfNeeded: value >> 29)) | 0x01
    let part2 = UInt8(truncatingIfNeeded: value >> 22)
    let part3 = UInt8(truncatingIfNeeded: value >> 14) | 0x01
    let part4 = UInt8(truncatingIfNeeded: value >> 7)
    let part5 = UInt8(truncatingIfNeeded: value << 1) | 0x01
    return [part1, part2, part3, part4, part5]
  }
}

extension ISOMediaTimestamp {
  static let videoTimeScale: Int32 = 90000
  static let audioTimeScale: Int32 = 44100

  public init(prefix: Prefix, time: MediaTimestamp, timeScale: Int32) {
    let converted: Int64
    let value = time.value
    let toScale = Int64(timeScale)
    let fromScale = Int64(time.scale)
    if value < fromScale && toScale < fromScale {
      converted = (value * toScale) / fromScale
    } else if toScale < fromScale {
      converted = (value / fromScale) * toScale
    } else {
      converted = value * (toScale / fromScale)
    }
    self.init(
      prefix: prefix,
      truncating: UInt64(converted)
    )
  }

  func toMediaTimestamp(timeScale: Int32) -> MediaTimestamp {
    MediaTimestamp(value: Int64(value), scale: timeScale)
  }

  init(prefix: Prefix, videoTime: MediaTimestamp) {
    self.init(prefix: prefix, time: videoTime, timeScale: Self.videoTimeScale)
  }

  init(prefix: Prefix, audioTime: MediaTimestamp) {
    self.init(prefix: prefix, time: audioTime, timeScale: Self.audioTimeScale)
  }

  var videoMediaTimestamp: MediaTimestamp {
    toMediaTimestamp(timeScale: Self.videoTimeScale)
  }

  var audioMediaTimestamp: MediaTimestamp {
    toMediaTimestamp(timeScale: Self.audioTimeScale)
  }
}

extension ISOMediaTimestamp {
  public enum Prefix: UInt8, Equatable, Sendable {
    case pts = 0b0010
    case ptsPrecedingDts = 0b0011
    case dts = 0b0001
  }
}

extension ISOMediaTimestamp.Prefix: CustomStringConvertible {
  public var description: String {
    switch self {
    case .pts: "PTS"
    case .ptsPrecedingDts: "PTS preceding DTS"
    case .dts: "DTS"
    }
  }
}

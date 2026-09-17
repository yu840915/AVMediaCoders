import LogContext

public typealias MediaTimeScale = Int32
public struct MediaTimestamp: Equatable, Sendable, LogContextReadable {

  public let value: Int64
  public let scale: MediaTimeScale
  public var isValid: Bool {
    value >= 0 && scale > 0
  }
  public var logContext: LogContext {
    LogContext {
      $0["value"] = value
      $0["scale"] = scale
      $0["inSeconds"] = "\(value/Int64(scale))+\(value%Int64(scale))/\(scale)"
    }
  }

  public init(value: Int64, scale: Int32) {
    self.value = value
    self.scale = scale
  }

  public static func + (lhs: MediaTimestamp, rhs: MediaTimestamp) -> MediaTimestamp {
    precondition(lhs.scale == rhs.scale, "Cannot add MediaTimestamps with different scales")
    return MediaTimestamp(value: lhs.value + rhs.value, scale: lhs.scale)
  }

  public static func - (lhs: MediaTimestamp, rhs: MediaTimestamp) -> MediaTimestamp {
    precondition(lhs.scale == rhs.scale, "Cannot subtract MediaTimestamps with different scales")
    return MediaTimestamp(value: lhs.value - rhs.value, scale: lhs.scale)
  }
}

extension MediaTimeScale {
  public static let video: MediaTimeScale = 90000
  public static let audio: MediaTimeScale = 44100
}

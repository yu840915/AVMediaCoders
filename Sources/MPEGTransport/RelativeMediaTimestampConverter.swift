public struct RelativeMediaTimestampConverter: Sendable {
  public let strategy: Strategy
  public private(set) var initialTimestamp: MediaTimestamp?
  private var initialLocalTimestamp: MediaTimestamp

  public init(initialTimestamp: MediaTimestamp? = nil, strategy: Strategy = .startFromZero) {
    self.initialTimestamp = initialTimestamp
    initialLocalTimestamp = MediaTimestamp(value: 0, scale: 1000_000)
    self.strategy = strategy
  }

  public mutating func convert(_ timestamp: MediaTimestamp) -> MediaTimestamp {
    if let initialTimestamp {
      return timestamp - initialTimestamp + initialLocalTimestamp
    } else {
      initialTimestamp = timestamp
      initialLocalTimestamp =
        switch strategy {
        case .startFromZero:
          MediaTimestamp(value: 0, scale: timestamp.scale)
        case .alignWithLocalClock(let localClockProvider):
          localClockProvider()
        }
      return MediaTimestamp(value: 0, scale: timestamp.scale) + initialLocalTimestamp
    }
  }
}

extension RelativeMediaTimestampConverter {
  public enum Strategy: Sendable {
    case startFromZero
    case alignWithLocalClock((@Sendable () -> MediaTimestamp))
  }
}

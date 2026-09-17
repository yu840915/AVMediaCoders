import LogContext
import OSLog

enum Loggers: String {
  case tsPacketizing
  case tsDepacketizing
  case muxing
  case demuxing

  func build() -> Logger {
    Logger(subsystem: "com.teleshot.MPEGTransport", category: rawValue)
  }
}

extension LogContext.Label {
  static let debugPacketizationIO = LogContext.Label(
    rawValue: "DEBUG_PACKETIZATION_IO"
  )
}

extension LogContext.Key {
  static let size = LogContext.Key(rawValue: "size")
}

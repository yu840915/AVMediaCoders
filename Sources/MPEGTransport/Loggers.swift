import OSLog

enum Loggers: String {
  case tsPacketizing
  case tsDepacketizing
  case muxing
  case demuxing

  func build() -> Logger {
    Logger(subsystem: "com.teleshot.MPEGTransport", category: self.rawValue)
  }
}

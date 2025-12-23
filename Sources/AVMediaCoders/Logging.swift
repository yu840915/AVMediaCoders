import LogContext
import OSLog

enum Loggers: String {
  case compressing
  case decompressing
  case encoding
  case decoding
  case packetizing
  case depacketizing

  func build() -> Logger {
    Logger(subsystem: "com.teleshot.AVMediaCoders", category: self.rawValue)
  }
}

extension LogContext.Label {
  static let videoCompressor = LogContext.Label(rawValue: "videoCompressor")
  static let videoDecompressor = LogContext.Label(rawValue: "videoDecompressor")
  static let videoCodec = LogContext.Label(rawValue: "videoCodec")
}

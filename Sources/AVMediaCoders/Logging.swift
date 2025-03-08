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

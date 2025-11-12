import Foundation

enum AVMediaCodersError: Error, Equatable {
  case framework(OSStatus)
  case cannotCreateCompressor
  case cannotCreateDecompressor
  case frameDropped
  case missingBuffer
}

func ensureSuccess(osStatus status: @autoclosure () -> OSStatus) throws {
  let status = status()
  guard status == noErr else {
    throw AVMediaCodersError.framework(status)
  }
}

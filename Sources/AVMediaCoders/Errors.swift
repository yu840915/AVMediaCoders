import Foundation

enum AVMediaCodersError: Error, Equatable {
  case framework(OSStatus)
  case cannotCreateCompressor
  case cannotCreateDecompressor
  case frameDropped
  case missingBuffer
  case invalidHEVC(HEVCNALUnitError)
}

func ensureSuccess(osStatus status: @autoclosure () -> OSStatus) throws {
  let status = status()
  guard status == noErr else {
    throw AVMediaCodersError.framework(status)
  }
}

enum HEVCNALUnitError: Error, Equatable {
  case invalidNALUnitHeaderLength
  case nonZeroForbiddenBit
  case invalidNALUnitType
}

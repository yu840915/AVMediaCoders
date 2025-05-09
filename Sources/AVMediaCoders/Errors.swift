import Foundation

enum AVMediaCodersError: Error, Equatable {
  case framework(OSStatus)
  case cannotCreateCompressor
  case cannotCreateDecompressor
  case frameDropped
  case missingBuffer
  case invalidHEVC(HEVCNALUnitError)
  case invalidPES(PESError)
  case invalidTS(TSError)
  case muxer(MuxerError)
  case invalidISOTimestampPrefix
  case bufferTooShort
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

enum PESError: Error, Equatable {
  case invalidStartCode
  case invalidMarkerBit
  case invalidScramblingControl
  case invalidPtsDtsFlag
  case headerDataTooShort
  case conflictingPtsDtsFlag
  case invalidStreamID
}

enum TSError: Error, Equatable {
  case invalidSyncByte
  case unexpectedPID
  case invalidHeader
  case sectionLengthOutOfBounds
  case discountinuityDetected
  case invalidCRC
  case invalidSectionNumber
  case inconsistentVersion
}

enum MuxerError: Error, Equatable {
  case dataStreamPIDMismatch
}

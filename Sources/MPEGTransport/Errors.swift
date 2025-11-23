public enum MPEGTransportError: Error, Equatable, Sendable {
  case bufferTooShort
  case invalidISOTimestampPrefix
  case invalidHEVC(HEVCNALUnitError)
  case invalidPES(PESError)
  case invalidTS(TSError)
  case muxer(MuxerError)
  case demuxer(DemuxerError)
}

public enum HEVCNALUnitError: Error, Equatable, Sendable {
  case invalidNALUnitHeaderLength
  case nonZeroForbiddenBit
  case invalidNALUnitType
}

public enum PESError: Error, Equatable, Sendable {
  case invalidStartCode
  case invalidMarkerBit
  case invalidScramblingControl
  case invalidPtsDtsFlag
  case headerDataTooShort
  case conflictingPtsDtsFlag
  case invalidStreamID
}

public enum TSError: Error, Equatable, Sendable {
  case invalidSyncByte
  case unexpectedPID
  case invalidHeader
  case sectionLengthOutOfBounds
  case discountinuityDetected
  case invalidCRC
  case invalidSectionNumber
  case inconsistentVersion
}

public enum MuxerError: Error, Equatable, Sendable {
  case dataStreamPIDMismatch
}

public enum DemuxerError: Error, Equatable, Sendable {
  case missingVideoStream
  case missingAudioStream
}

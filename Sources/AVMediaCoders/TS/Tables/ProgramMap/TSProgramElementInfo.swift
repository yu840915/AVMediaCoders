struct TSProgramElementInfo: Equatable, Sendable {
  let streamType: TSStreamType
  let elementaryPID: TSPID
  let byteRepresentation: ByteRepresentation
  var ESInfo: [UInt8] {
    byteRepresentation.ESInfo
  }
  var bytes: [UInt8] {
    byteRepresentation.bytes
  }

  init(
    streamType: TSStreamType,
    elementaryPID: TSPID,
    ESInfo: [UInt8]
  ) {
    self.streamType = streamType
    self.elementaryPID = elementaryPID
    byteRepresentation = ByteRepresentation(
      streamType: streamType.value,
      elementaryPID: elementaryPID.value,
      ESInfo: ESInfo
    )
  }

  init(bytes: [UInt8]) throws {
    byteRepresentation = try ByteRepresentation(bytes: bytes)
    streamType = TSStreamType(rawValue: byteRepresentation.streamType)
    elementaryPID = try TSPID(rawValue: byteRepresentation.elementaryPID)
  }
}

extension TSProgramElementInfo {
  struct ByteRepresentation: Equatable, Sendable {
    let streamType: UInt8
    let elementaryPID: UInt16
    let ESInfoLength: UInt16
    let ESInfo: [UInt8]

    init(
      streamType: UInt8,
      elementaryPID: UInt16,
      ESInfo: [UInt8]
    ) {
      self.streamType = streamType
      self.elementaryPID = elementaryPID
      self.ESInfoLength = UInt16(ESInfo.count)
      self.ESInfo = ESInfo
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 5 else {
        throw AVMediaCodersError.bufferTooShort
      }
      streamType = bytes[0]
      elementaryPID = UInt16(bytes[1] & 0x1F) << 8 | UInt16(bytes[2])
      ESInfoLength = UInt16(bytes[3] & 0x0F) << 8 | UInt16(bytes[4])
      let infoBytes = bytes.dropFirst(5)
      let infoLength = Int(ESInfoLength)
      guard infoLength <= infoBytes.count else {
        throw AVMediaCodersError.bufferTooShort
      }
      ESInfo = Array(infoBytes.prefix(infoLength))
    }

    var bytes: [UInt8] {
      let pidBytes = elementaryPID.bigEndianBytes
      let part2 = pidBytes[0] & 0x1F
      let part3 = pidBytes[1]
      let lenBytes = ESInfoLength.bigEndianBytes
      let part4 = lenBytes[0] & 0x0F
      let part5 = lenBytes[1]
      return [streamType, part2, part3, part4, part5] + ESInfo
    }
  }
}

enum TSStreamType: Equatable {
  case videoMPEG1
  case videoMPEG2
  case audioMPEG1
  case audioMPEG2HalvedSampleRate
  case subtitle
  case mhegFeatures
  case audioADTSAAC
  case videoAVC
  case videoHEVC
  case audioATSCDolbyDigital
  case IPMP
  case unsupported(value: UInt8)

  init(rawValue: UInt8) {
    switch rawValue {
    case 0x01: self = .videoMPEG1
    case 0x02: self = .videoMPEG2
    case 0x03: self = .audioMPEG1
    case 0x04: self = .audioMPEG2HalvedSampleRate
    case 0x05: self = .subtitle
    case 0x06: self = .mhegFeatures
    case 0x0F: self = .audioADTSAAC
    case 0x1B: self = .videoAVC
    case 0x24: self = .videoHEVC
    case 0x87: self = .audioATSCDolbyDigital
    case 0x7F: self = .IPMP
    default: self = .unsupported(value: rawValue)
    }
  }

  var value: UInt8 {
    switch self {
    case .videoMPEG1: 0x01
    case .videoMPEG2: 0x02
    case .audioMPEG1: 0x03
    case .audioMPEG2HalvedSampleRate: 0x04
    case .subtitle: 0x05
    case .mhegFeatures: 0x06
    case .audioADTSAAC: 0x0F
    case .videoAVC: 0x1B
    case .videoHEVC: 0x24
    case .audioATSCDolbyDigital: 0x87
    case .IPMP: 0x7F
    case .unsupported(let value): value
    }
  }
}

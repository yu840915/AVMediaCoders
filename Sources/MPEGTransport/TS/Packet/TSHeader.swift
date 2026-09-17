import LogContext

struct TSHeader: Equatable, Sendable, LogContextReadable {
  let byteRepresentation: ByteRepresentation
  var isStartOfPayload: Bool {
    byteRepresentation.payloadUnitStartIndicator
  }
  var adaptationFieldControl: AdaptationFieldControl {
    byteRepresentation.adaptationFieldControl
  }
  let PID: TSPID
  var pid: UInt16 {
    byteRepresentation.pid
  }
  var continuityCounter: UInt8 {
    byteRepresentation.continuityCounter
  }
  var bytes: [UInt8] {
    byteRepresentation.bytes
  }

  var logContext: LogContext {
    LogContext {
      $0["PID"] = PID
      $0["counter"] = continuityCounter
      $0.setDebugDetail {
        $0["isStart"] = isStartOfPayload
        $0["adaptationField"] = adaptationFieldControl
      }
    }
  }

  init(
    isStartOfPayload: Bool,
    PID: TSPID,
    adaptationFieldControl: AdaptationFieldControl,
    continuityCounter: UInt8
  ) {
    self.PID = PID
    byteRepresentation = ByteRepresentation(
      transportErrorIndicator: false,
      payloadUnitStartIndicator: isStartOfPayload,
      pid: PID.value,
      adaptationFieldControl: adaptationFieldControl,
      continuityCounter: continuityCounter
    )
  }

  init(bytes: [UInt8]) throws {
    byteRepresentation = try ByteRepresentation(bytes: bytes)
    PID = try TSPID(rawValue: byteRepresentation.pid)
  }
}

extension TSHeader {
  struct ByteRepresentation: Equatable, Sendable {
    let syncByte: UInt8 = 0x47
    let transportErrorIndicator: Bool
    let payloadUnitStartIndicator: Bool
    let transportPriority: Bool
    let pid: UInt16
    let scramblingControl: ScramblingControl
    let adaptationFieldControl: AdaptationFieldControl
    let continuityCounter: UInt8

    var bytes: [UInt8] {
      var part2: UInt8 = 0
      var part3: UInt8 = 0
      var part4: UInt8 = 0
      part2 |= (transportErrorIndicator ? 0b10000000 : 0)
      part2 |= (payloadUnitStartIndicator ? 0b01000000 : 0)
      part2 |= (transportPriority ? 0b00100000 : 0)
      part2 |= UInt8(pid >> 8) & 0b00011111
      part3 |= UInt8(pid & 0xFF)
      part4 |= (scramblingControl.rawValue << 6)
      part4 |= (adaptationFieldControl.rawValue << 4)
      part4 |= continuityCounter & 0b00001111
      return [syncByte, part2, part3, part4]
    }

    init(
      transportErrorIndicator: Bool = false,
      payloadUnitStartIndicator: Bool,
      transportPriority: Bool = false,
      pid: UInt16,
      scramblingControl: ScramblingControl = .notScrambling,
      adaptationFieldControl: AdaptationFieldControl,
      continuityCounter: UInt8
    ) {
      self.transportErrorIndicator = transportErrorIndicator
      self.payloadUnitStartIndicator = payloadUnitStartIndicator
      self.transportPriority = transportPriority
      self.pid = pid
      self.scramblingControl = scramblingControl
      self.adaptationFieldControl = adaptationFieldControl
      self.continuityCounter = continuityCounter
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 4 else {
        throw MPEGTransportError.bufferTooShort
      }
      try self.init(
        part1: bytes[0],
        part2: bytes[1],
        part3: bytes[2],
        part4: bytes[3]
      )
    }

    init(part1: UInt8, part2: UInt8, part3: UInt8, part4: UInt8) throws {
      guard part1 == syncByte else {
        throw MPEGTransportError.invalidTS(.invalidSyncByte)
      }
      transportErrorIndicator = (part2 & 0b10000000) != 0
      payloadUnitStartIndicator = (part2 & 0b01000000) != 0
      transportPriority = (part2 & 0b00100000) != 0
      pid = UInt16(part2 & 0b00011111) << 8 | UInt16(part3)
      scramblingControl = ScramblingControl(rawValue: (part4 & 0b11000000) >> 6)!
      adaptationFieldControl = AdaptationFieldControl(rawValue: (part4 & 0b00110000) >> 4)!
      continuityCounter = part4 & 0b00001111
    }
  }

  enum ScramblingControl: UInt8, Equatable, Sendable {
    case notScrambling = 0b00
    case reserved = 0b01
    case evenKeyScrambled = 0b10
    case oddKeyScrambled = 0b11
  }

  enum AdaptationFieldControl: UInt8, Equatable, Sendable {
    case reserved = 0b00
    case payloadOnly = 0b01
    case adaptationFieldOnly = 0b10
    case adaptationFieldAndPayload = 0b11
  }
}

extension TSHeader.AdaptationFieldControl: CustomStringConvertible {
  public var description: String {
    switch self {
    case .reserved: return "Reserved"
    case .payloadOnly: return "Payload"
    case .adaptationFieldOnly: return "Adaptation"
    case .adaptationFieldAndPayload: return "Both"
    }
  }
}

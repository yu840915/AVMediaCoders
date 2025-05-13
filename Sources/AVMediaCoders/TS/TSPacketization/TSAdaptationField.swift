public struct TSAdaptationField: Equatable, Sendable {
  static let minimumLength: UInt8 = 2
  static let maximumLength: UInt8 = 184
  let length: UInt8
  let pcr: TSClockReference?
  let opcr: TSClockReference?
  var randomAccessIndicator: Bool {
    byteRepresentation.randomAccessIndicator
  }
  let spliceCountdown: UInt8?
  let transportPrivateData: [UInt8]?
  let byteRepresentation: ByteRepresentation

  let bytes: [UInt8]

  init(
    remainingDataLength: Int,
    pcr: TSClockReference? = nil,
    opcr: TSClockReference? = nil,
    randomAccessIndicator: Bool = false
  ) {
    self.pcr = pcr
    self.opcr = opcr
    byteRepresentation = ByteRepresentation(
      discontinuityIndicator: false,
      randomAccessIndicator: randomAccessIndicator,
      elementaryStreamPriorityIndicator: false,
      pcrFlag: pcr != nil,
      opcrFlag: opcr != nil,
      splicingPointFlag: false,
      transportPrivateDataFlag: false,
      adaptationFieldExtensionFlag: false
    )
    self.spliceCountdown = nil
    self.transportPrivateData = nil
    let bytes: [UInt8] = byteRepresentation.bytes + (pcr?.bytes ?? []) + (opcr?.bytes ?? [])
    let fieldLength = UInt8(bytes.count)
    let stuffingLength = UInt8(
      max(
        Int(TSAdaptationField.maximumLength - 1 - fieldLength) - remainingDataLength,
        0
      )
    )
    self.length = fieldLength + stuffingLength
    self.bytes = [length] + bytes + Array(repeating: 0xFF, count: Int(stuffingLength))
  }

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 2 else {
      throw AVMediaCodersError.bufferTooShort
    }
    byteRepresentation = try ByteRepresentation(bytes: Array(bytes[1...1]))
    var remainingBytes = Array(bytes[2...])
    length = bytes[0]
    guard bytes.count > length else {
      throw AVMediaCodersError.bufferTooShort
    }
    if byteRepresentation.pcrFlag {
      pcr = try TSClockReference(bytes: Array(remainingBytes[0...5]))
      remainingBytes = Array(remainingBytes[6...])
    } else {
      pcr = nil
    }
    if byteRepresentation.opcrFlag {
      opcr = try TSClockReference(bytes: Array(remainingBytes[0...5]))
      remainingBytes = Array(remainingBytes[6...])
    } else {
      opcr = nil
    }
    if byteRepresentation.splicingPointFlag {
      spliceCountdown = remainingBytes[0]
      remainingBytes = Array(remainingBytes[1...])
    } else {
      spliceCountdown = nil
    }
    if byteRepresentation.transportPrivateDataFlag {
      let length = remainingBytes[0]
      transportPrivateData = Array(remainingBytes[1...Int(length)])
      remainingBytes = Array(remainingBytes[Int(length + 1)...])
    } else {
      transportPrivateData = nil
    }
    self.bytes = Array(bytes[0...Int(length)])
  }
}

extension TSAdaptationField {
  struct ByteRepresentation: Equatable, Sendable {
    let discontinuityIndicator: Bool
    let randomAccessIndicator: Bool
    let elementaryStreamPriorityIndicator: Bool
    let pcrFlag: Bool
    let opcrFlag: Bool
    let splicingPointFlag: Bool
    let transportPrivateDataFlag: Bool
    let adaptationFieldExtensionFlag: Bool

    var bytes: [UInt8] {
      var value: UInt8 = 0
      value |= (discontinuityIndicator ? 0b10000000 : 0)
      value |= (randomAccessIndicator ? 0b01000000 : 0)
      value |= (elementaryStreamPriorityIndicator ? 0b00100000 : 0)
      value |= (pcrFlag ? 0b00010000 : 0)
      value |= (opcrFlag ? 0b00001000 : 0)
      value |= (splicingPointFlag ? 0b00000100 : 0)
      value |= (transportPrivateDataFlag ? 0b00000010 : 0)
      value |= (adaptationFieldExtensionFlag ? 0b00000001 : 0)
      return [value]
    }

    init(
      discontinuityIndicator: Bool = false,
      randomAccessIndicator: Bool = false,
      elementaryStreamPriorityIndicator: Bool = false,
      pcrFlag: Bool = false,
      opcrFlag: Bool = false,
      splicingPointFlag: Bool = false,
      transportPrivateDataFlag: Bool = false,
      adaptationFieldExtensionFlag: Bool = false
    ) {
      self.discontinuityIndicator = discontinuityIndicator
      self.randomAccessIndicator = randomAccessIndicator
      self.elementaryStreamPriorityIndicator = elementaryStreamPriorityIndicator
      self.pcrFlag = pcrFlag
      self.opcrFlag = opcrFlag
      self.splicingPointFlag = splicingPointFlag
      self.transportPrivateDataFlag = transportPrivateDataFlag
      self.adaptationFieldExtensionFlag = adaptationFieldExtensionFlag
    }

    init(bytes: [UInt8]) throws {
      let byte = bytes[0]
      self.discontinuityIndicator = (byte & 0b10000000) != 0
      self.randomAccessIndicator = (byte & 0b01000000) != 0
      self.elementaryStreamPriorityIndicator = (byte & 0b00100000) != 0
      self.pcrFlag = (byte & 0b00010000) != 0
      self.opcrFlag = (byte & 0b00001000) != 0
      self.splicingPointFlag = (byte & 0b00000100) != 0
      self.transportPrivateDataFlag = (byte & 0b00000010) != 0
      self.adaptationFieldExtensionFlag = (byte & 0b00000001) != 0
    }
  }
}

extension TSAdaptationField: CustomDebugStringConvertible {
  public var debugDescription: String {
    "TSAdaptationField(length: \(length))"
  }
}

struct AdaptationFieldExtension: Equatable, Sendable {
  let length: UInt8
  let legalTimeWindowFlag: Bool
  let piecewiseRateFlag: Bool
  let seamlessSpliceFlag: Bool
  let legalTimeWindowOffset: UInt16
  let piecewiseRate: UInt32
  let spliceType: UInt8
  let dtsNextAccessUnit: UInt64
}

extension AdaptationFieldExtension {
  struct ByteRepresentation: Equatable, Sendable {
    let length: UInt8
    let legalTimeWindowFlag: Bool
    let piecewiseRateFlag: Bool
    let seamlessSpliceFlag: Bool
  }
}

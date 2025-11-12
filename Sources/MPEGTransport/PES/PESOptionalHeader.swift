import CoreMedia

/// PES Optional Header
public struct PESHeaderExtension: Equatable, Sendable {
  var scramblingControl: ScramblingControl {
    flags.scramblingControl
  }
  var dataAlignmentIndicator: Bool {
    flags.dataAlignmentIndicator
  }
  var copyRight: Bool {
    flags.copyRight
  }
  var isOriginal: Bool {
    flags.isOriginal
  }
  let ptsAndDts: PtsAndDts
  let flags: PESHeaderExtensionFlags

  public let bytes: [UInt8]

  public init(
    scramblingControl: ScramblingControl = .notScrambling,
    dataAlignmentIndicator: Bool = false,
    copyRight: Bool = false,
    isOriginal: Bool = true,
    ptsAndDts: PtsAndDts
  ) {
    self.ptsAndDts = ptsAndDts
    let dataBytes = ptsAndDts.bytes
    var flags = PESHeaderExtensionFlags()
    flags.scramblingControl = scramblingControl
    flags.dataAlignmentIndicator = dataAlignmentIndicator
    flags.copyRight = copyRight
    flags.ptsAndDts = ptsAndDts.toFlag()
    flags.isOriginal = isOriginal
    flags.headerDataLength = UInt8(dataBytes.count)
    self.bytes = flags.bytes + dataBytes
    self.flags = flags
  }

  init(bytes: [UInt8]) throws {
    let flags = try PESHeaderExtensionFlags(bytes: bytes)
    self.flags = flags
    let dataBytes = Array(bytes.suffix(from: 3))
    guard dataBytes.count >= flags.headerDataLength else {
      throw MPEGTransportError.invalidPES(.headerDataTooShort)
    }
    ptsAndDts = try PtsAndDts(
      flag: flags.ptsAndDts,
      bytes: Array(dataBytes.prefix(Int(flags.headerDataLength)))
    )
    self.bytes = flags.bytes + ptsAndDts.bytes
  }
}

extension PESHeaderExtension {
  public enum ScramblingControl: UInt8, Equatable, Sendable {
    case notScrambling = 0b00
    case reserved = 0b01
    case evenKeyScrambled = 0b10
    case oddKeyScrambled = 0b11
  }

  public enum PtsAndDts: Equatable, Sendable {
    case none
    case pts(CMTime)
    case ptsAndDts(pts: CMTime, dts: CMTime)

    var bytes: [UInt8] {
      switch self {
      case .none: return []
      case .pts(let pts): return ISOMediaTimestamp(prefix: .pts, videoTime: pts).bytes
      case .ptsAndDts(let pts, let dts):
        return ISOMediaTimestamp(prefix: .ptsPrecedingDts, videoTime: pts).bytes
          + ISOMediaTimestamp(prefix: .dts, videoTime: dts).bytes
      }
    }
    var pts: CMTime? {
      return switch self {
      case .none: nil
      case .pts(let pts): pts
      case .ptsAndDts(let pts, _): pts
      }
    }
    var dts: CMTime? {
      return switch self {
      case .none, .pts: nil
      case .ptsAndDts(_, let dts): dts
      }
    }

    public init(pts: CMTime, dts: CMTime) {
      guard pts.isValid else {
        self = .none
        return
      }
      if dts.isValid {
        self = .ptsAndDts(pts: pts, dts: dts)
      } else {
        self = .pts(pts)
      }
    }

    func toFlag() -> PESHeaderExtensionFlags.PtsDtsFlag {
      switch self {
      case .none: .none
      case .pts: .pts
      case .ptsAndDts: .ptsAndDts
      }
    }
  }
}

extension PESHeaderExtension.PtsAndDts {
  init(flag: PESHeaderExtensionFlags.PtsDtsFlag, bytes: [UInt8]) throws {
    switch flag {
    case .none:
      self = .none
    case .pts:
      try self.init(pts: bytes)
    case .ptsAndDts:
      try self.init(ptsAndDts: bytes)
    }
  }

  init(pts: [UInt8]) throws {
    let ts = try ISOMediaTimestamp(bytes: pts)
    guard ts.prefix == .pts else {
      throw MPEGTransportError.invalidPES(.conflictingPtsDtsFlag)
    }
    self = .pts(ts.videoCMTime)
  }

  init(ptsAndDts: [UInt8]) throws {
    let pts = try ISOMediaTimestamp(bytes: ptsAndDts)
    guard pts.prefix == .ptsPrecedingDts else {
      throw MPEGTransportError.invalidPES(.conflictingPtsDtsFlag)
    }
    let dts = try ISOMediaTimestamp(bytes: Array(ptsAndDts.suffix(from: 5)))
    guard dts.prefix == .dts else {
      throw MPEGTransportError.invalidPES(.conflictingPtsDtsFlag)
    }
    self = .ptsAndDts(pts: pts.videoCMTime, dts: dts.videoCMTime)
  }
}

struct PESHeaderExtensionFlags: Equatable {
  var scramblingControl: PESHeaderExtension.ScramblingControl = .notScrambling
  var priority: Bool = false
  var dataAlignmentIndicator: Bool = false
  var copyRight: Bool = false
  var isOriginal: Bool = false  // originalOrCopy
  var ptsAndDts: PtsDtsFlag = .none
  var escrFlag: Bool = false
  var esRateFlag: Bool = false
  var dsmTrickModeFlag: Bool = false
  var additionalCopyInfoFlag: Bool = false
  var crcFlag: Bool = false
  var extensionFlag: Bool = false
  var headerDataLength: UInt8 = 0

  init() {}

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 3 else {
      throw MPEGTransportError.bufferTooShort
    }
    try self.init(part1: bytes[0], part2: bytes[1], part3: bytes[2])
  }

  init(part1: UInt8, part2: UInt8, part3: UInt8) throws {
    guard part1 & 0b1100_0000 == 0b1000_0000 else {
      throw MPEGTransportError.invalidPES(.invalidMarkerBit)
    }
    guard
      let scramblingControl = PESHeaderExtension.ScramblingControl(
        rawValue: (part1 & 0b0011_0000) >> 4
      )
    else {
      throw MPEGTransportError.invalidPES(.invalidScramblingControl)
    }
    guard let ptsAndDts = PtsDtsFlag(rawValue: part2 >> 6) else {
      throw MPEGTransportError.invalidPES(.invalidPtsDtsFlag)
    }
    self.scramblingControl = scramblingControl
    self.priority = part1 & 0b0000_1000 != 0
    self.dataAlignmentIndicator = part1 & 0b0000_0100 != 0
    self.copyRight = part1 & 0b0000_0010 != 0
    self.isOriginal = part1 & 0b0000_0001 != 0

    self.ptsAndDts = ptsAndDts
    self.escrFlag = part2 & 0b0010_0000 != 0
    self.esRateFlag = part2 & 0b0001_0000 != 0
    self.dsmTrickModeFlag = part2 & 0b0000_1000 != 0
    self.additionalCopyInfoFlag = part2 & 0b0000_0100 != 0
    self.crcFlag = part2 & 0b0000_0010 != 0
    self.extensionFlag = part2 & 0b0000_0001 != 0

    self.headerDataLength = part3
  }

  var bytes: [UInt8] {
    var part1: UInt8 = 0b1000_0000
    part1 |= scramblingControl.rawValue << 4
    if priority { part1 |= 0b0000_1000 }
    if dataAlignmentIndicator { part1 |= 0b0000_0100 }
    if copyRight { part1 |= 0b0000_0010 }
    if isOriginal { part1 |= 0b0000_0001 }

    var part2: UInt8 = 0b0000_0000
    part2 |= ptsAndDts.rawValue << 6
    if escrFlag { part2 |= 0b0010_0000 }
    if esRateFlag { part2 |= 0b0001_0000 }
    if dsmTrickModeFlag { part2 |= 0b0000_1000 }
    if additionalCopyInfoFlag { part2 |= 0b0000_0100 }
    if crcFlag { part2 |= 0b0000_0010 }
    if extensionFlag { part2 |= 0b0000_0001 }

    let part3: UInt8 = headerDataLength

    return [part1, part2, part3]
  }

  enum PtsDtsFlag: UInt8 {
    case none = 0b00
    case pts = 0b10
    case ptsAndDts = 0b11
  }
}

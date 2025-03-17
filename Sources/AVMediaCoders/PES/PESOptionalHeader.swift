struct PESOptionalHeader {
  var scramblingControl: ScramblingControl
  var priority: Bool
  var dataAlignmentIndicator: Bool
  var copyRight: Bool
  var originalOrCopy: Bool
  var ptsAndDts: PtsAndDts

  let escrFlag: Bool
  let esRateFlag: Bool
  let dsmTrickModeFlag: Bool
  let additionalCopyInfoFlag: Bool
  let crcFlag: Bool
  let extensionFlag: Bool
  let pesHeaderLength: UInt8
}

extension PESOptionalHeader {
  struct BitLayout {
    let markerBits: UInt8
    let scramblingControl: UInt8
    let priority: Bool
    let dataAlignmentIndicator: Bool
    let copyRight: Bool
    let originalOrCopy: Bool
  }

  enum ScramblingControl: UInt8 {
    case notScrambling = 0b00
    case reserved = 0b01
    case evenKeyScrambled = 0b10
    case oddKeyScrambled = 0b11
  }

  enum PtsDtsIndicator: UInt8 {
    case none = 0b00
    case ptsOnly = 0b10
    case both = 0b11
  }
  enum PtsAndDts {
    case none
    case pts(ISOMediaTimestamp)
    case ptsAndDts(pts: ISOMediaTimestamp, dts: ISOMediaTimestamp)
  }
}

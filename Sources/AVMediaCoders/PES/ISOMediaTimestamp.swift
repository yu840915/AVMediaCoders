struct ISOMediaTimestamp: Equatable {
  enum Prefix: UInt8, Equatable {
    case pts = 0b0010
    case ptsPrecedingDts = 0b0011
    case dts = 0b0001
  }
  let prefix: Prefix
  let value: UInt64
  init(prefix: Prefix, truncating: UInt64) {
    self.prefix = prefix
    self.value = truncating & 0x1_FFFF_FFFF
  }

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 5 else {
      throw AVMediaCodersError.bufferTooShort
    }
    try self.init(
      part1: bytes[0],
      part2: bytes[1],
      part3: bytes[2],
      part4: bytes[3],
      part5: bytes[4]
    )
  }

  init(part1: UInt8, part2: UInt8, part3: UInt8, part4: UInt8, part5: UInt8) throws {
    guard let prefix = Prefix(rawValue: part1 >> 4) else {
      throw AVMediaCodersError.invalidISOTimestampPrefix
    }
    self.prefix = prefix
    self.value =
      (UInt64(part1) & 0b1110) << 29
      | UInt64(part2) << 22
      | (UInt64(part3) >> 1) << 15
      | UInt64(part4) << 7
      | UInt64(part5) >> 1
  }

  var bytes: [UInt8] {
    let big = value
    let part1 = UInt8(prefix.rawValue << 4 | UInt8(truncatingIfNeeded: big >> 29)) | 0x01
    let part2 = UInt8(truncatingIfNeeded: big >> 22)
    let part3 = UInt8(truncatingIfNeeded: big >> 14) | 0x01
    let part4 = UInt8(truncatingIfNeeded: big >> 7)
    let part5 = UInt8(truncatingIfNeeded: big << 1) | 0x01
    return [part1, part2, part3, part4, part5]
  }
}

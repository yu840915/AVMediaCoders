import CoreMedia

public struct TSClockReference: Equatable, Sendable {
  let value: UInt64
  let valueScale = 90000

  let ext: UInt16
  let extScale = 27_000_000

  public init(
    _ value: UInt64,
    ext: UInt16 = 0
  ) {
    self.value = value & 0x1_FFFF_FFFF
    self.ext = ext & 0x1FF
  }

  init(bytes: [UInt8]) throws {
    let value32 = try UInt32(bigEndianBytes: Array(bytes[0...3]))
    value = UInt64(value32) << 1 | UInt64(bytes[4] & 0x80) >> 7
    ext = try UInt16(bigEndianBytes: Array(bytes[4...5])) & 0x7FFF
  }

  var bytes: [UInt8] {
    let upperValueBytes = UInt32(bigEndian: UInt32(value >> 1)).bigEndianBytes
    let lastValueByte: UInt8 = value & 0x01 == 0 ? 0x00 : 0x80
    let extBytes = ext.bigEndianBytes
    return upperValueBytes + [lastValueByte | extBytes[0], extBytes[1]]
  }
}

extension TSClockReference {
  init(cmTime: CMTime) {
    //TODO: implement
    value = 0
    ext = 0
  }
}

import Foundation

extension UInt32 {
  public var bigEndianBytes: [UInt8] {
    var lenBytes = [UInt8](repeating: 0, count: 4)
    var len = bigEndian
    memcpy(&lenBytes, &len, 4)
    return lenBytes
  }

  public init(bigEndianBytes: [UInt8]) throws {
    var len: UInt32 = 0
    memcpy(&len, bigEndianBytes, 4)
    self = UInt32(bigEndian: len)
  }
}

extension UInt64 {
  public var bigEndianBytes: [UInt8] {
    var lenBytes = [UInt8](repeating: 0, count: 8)
    var len = bigEndian
    memcpy(&lenBytes, &len, 8)
    return lenBytes
  }

  public init(bigEndianBytes: [UInt8]) throws {
    var len: UInt64 = 0
    memcpy(&len, bigEndianBytes, 8)
    self = UInt64(bigEndian: len)
  }
}

extension UInt16 {
  public var bigEndianBytes: [UInt8] {
    var lenBytes = [UInt8](repeating: 0, count: 2)
    var len = bigEndian
    memcpy(&lenBytes, &len, 2)
    return lenBytes
  }

  public init(bigEndianBytes: [UInt8]) throws {
    var len: UInt16 = 0
    memcpy(&len, bigEndianBytes, 2)
    self = UInt16(bigEndian: len)
  }
}

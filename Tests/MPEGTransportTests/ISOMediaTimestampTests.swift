import Testing

@testable import MPEGTransport

struct ISOMediaTimestampTests {
  @Test("Valid values", arguments: [0, 42, 0x1_FFFF_FFFF])
  func initWithValues(value: UInt64) async throws {
    let sut = ISOMediaTimestamp(prefix: .pts, truncating: value)

    #expect(sut.value == value)
  }

  @Test("Overflow values", arguments: [0x1_FFFF_FFFF, 0x2_0000_0000, UInt64.max])
  func initWithOverflow(value: UInt64) async throws {
    let sut = ISOMediaTimestamp(prefix: .pts, truncating: value)

    #expect(sut.value <= 0x1_FFFF_FFFF)
  }

  @Test
  func encodeToBytes() async throws {
    let sut = ISOMediaTimestamp(prefix: .pts, truncating: 123_456_789)

    let bytes = sut.bytes

    #expect(bytes.count == 5)
    #expect(bytes == [0b00100001, 0b00011101, 0b01101111, 0b10011010, 0b00101011])
  }

  @Test("Valid values", arguments: [0, 42, 0x1_FFFF_FFFF])
  func encodeAndDecode(value: UInt64) async throws {
    let sut = ISOMediaTimestamp(prefix: .pts, truncating: value)
    let bytes = sut.bytes
    let decoded = try ISOMediaTimestamp(bytes: bytes)

    #expect(sut == decoded)
  }

  @Test("Prefix values", arguments: [ISOMediaTimestamp.Prefix.pts, .ptsPrecedingDts, .dts])
  func encodeAndDecoePrefix(prefix: ISOMediaTimestamp.Prefix) async throws {
    let sut = ISOMediaTimestamp(prefix: prefix, truncating: 123_456_789)
    let bytes = sut.bytes
    let decoded = try ISOMediaTimestamp(bytes: bytes)

    #expect(sut == decoded)
  }

  @Test
  func convertFromCMTime() async throws {
    let time = MediaTimestamp(value: 123_456_789, scale: 90000)

    let sut = ISOMediaTimestamp(prefix: .pts, videoTime: time)
    let restored = sut.videoMediaTimestamp

    #expect(restored == MediaTimestamp(value: 123_456_789, scale: 90000))
  }

  @Test
  func convertFromCMTimeWithDifferentTimescale() async throws {
    let time = MediaTimestamp(value: 42, scale: 45000)

    let sut = ISOMediaTimestamp(prefix: .pts, videoTime: time)
    let restored = sut.videoMediaTimestamp

    #expect(restored == MediaTimestamp(value: 84, scale: 90000))
  }
}

import Testing

@testable import AVMediaCoders

struct TSClockReferenceTests {
  @Test
  func encodeIntegerPart() async throws {
    let sut = TSClockReference(0x1_FFFF_FFFF)

    let bytes = sut.bytes

    #expect(bytes == [0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00])
  }

  @Test
  func encodeFractionalPart() async throws {
    let sut = TSClockReference(0x1_FFFF_FFFF, ext: 0x1FF)

    let bytes = sut.bytes

    #expect(bytes == [0xFF, 0xFF, 0xFF, 0xFF, 0x81, 0xFF])
  }

  @Test(arguments: [
    TSClockReference(0x1_FFFF_FFFF),
    TSClockReference(0x1_FFFF_FFFF, ext: 0x1FF),
    TSClockReference(0x1_5555_5555, ext: 0x155),
    TSClockReference(0xAAAA_AAAA, ext: 0xAA),
    TSClockReference(0, ext: 0x1FF),
    TSClockReference(0),
  ])
  func encodeDecode(_ src: TSClockReference) async throws {
    let bytes = src.bytes

    let sut = try TSClockReference(bytes: bytes)

    #expect(sut == src)
  }

  @Test(arguments: [
    TSClockReference(0x3_FFFF_FFFF),
    TSClockReference(0x3_FFFF_FFFF, ext: 0x3FF),
    TSClockReference(0x2_0000_0000, ext: 0x200),
  ])
  func truncatingOverflowValueBySpec(_ src: TSClockReference) async throws {
    let bytes = src.bytes

    let sut = try TSClockReference(bytes: bytes)

    #expect(src.value <= 0x1_FFFF_FFFF)
    #expect(sut == src)
  }
}

import Testing

@testable import AVMediaCoders

struct PESOptionalHeaderFlagsTests {
  @Test
  func encodeAllFalseToBytes() async throws {
    var sut = PESHeaderExtensionFlags()
    sut.scramblingControl = .notScrambling
    sut.priority = false
    sut.dataAlignmentIndicator = false
    sut.copyRight = false
    sut.isOriginal = false
    sut.ptsAndDts = .none
    sut.escrFlag = false
    sut.esRateFlag = false
    sut.dsmTrickModeFlag = false
    sut.additionalCopyInfoFlag = false
    sut.crcFlag = false
    sut.extensionFlag = false
    sut.headerDataLength = 0

    #expect(sut.bytes == [0b1000_0000, 0b0000_0000, 0b0000_0000])
  }

  @Test
  func encodeAllTrueToBytes() async throws {
    var sut = PESHeaderExtensionFlags()
    sut.scramblingControl = .oddKeyScrambled
    sut.priority = true
    sut.dataAlignmentIndicator = true
    sut.copyRight = true
    sut.isOriginal = true
    sut.ptsAndDts = .ptsAndDts
    sut.escrFlag = true
    sut.esRateFlag = true
    sut.dsmTrickModeFlag = true
    sut.additionalCopyInfoFlag = true
    sut.crcFlag = true
    sut.extensionFlag = true
    sut.headerDataLength = 0b1111_1111

    #expect(sut.bytes == [0b1011_1111, 0b1111_1111, 0b1111_1111])
  }

  @Test
  func encodeOddTrueToBytes() async throws {
    var sut = PESHeaderExtensionFlags()
    sut.scramblingControl = .evenKeyScrambled
    sut.priority = true
    sut.dataAlignmentIndicator = false
    sut.copyRight = true
    sut.isOriginal = false
    sut.ptsAndDts = .pts
    sut.escrFlag = true
    sut.esRateFlag = false
    sut.dsmTrickModeFlag = true
    sut.additionalCopyInfoFlag = false
    sut.crcFlag = true
    sut.extensionFlag = false
    sut.headerDataLength = 0b1010_1010

    #expect(sut.bytes == [0b1010_1010, 0b1010_1010, 0b1010_1010])
  }

  @Test
  func encodeAndDecode() async throws {
    var sut = PESHeaderExtensionFlags()
    sut.scramblingControl = .reserved
    sut.priority = false
    sut.dataAlignmentIndicator = true
    sut.copyRight = false
    sut.isOriginal = true
    sut.ptsAndDts = .ptsAndDts
    sut.escrFlag = false
    sut.esRateFlag = true
    sut.dsmTrickModeFlag = false
    sut.crcFlag = true
    sut.additionalCopyInfoFlag = false
    sut.extensionFlag = true
    sut.headerDataLength = 0b01010_101

    let bytes = sut.bytes
    let decoded = try PESHeaderExtensionFlags(bytes: bytes)

    #expect(sut == decoded)
  }

  @Test
  func detectInvalidMarkerBit() async throws {
    #expect(throws: AVMediaCodersError.invalidPES(.invalidMarkerBit)) {
      try PESHeaderExtensionFlags(bytes: [0b0000_0000, 0b0000_0000, 0b0000_0000])
    }
  }

  @Test func detectInvalidPtsDtsFlag() async throws {
    #expect(throws: AVMediaCodersError.invalidPES(.invalidPtsDtsFlag)) {
      try PESHeaderExtensionFlags(bytes: [0b1000_0000, 0b0100_0000, 0b0000_0000])
    }
  }
}

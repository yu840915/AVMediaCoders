import Testing

@testable import AVMediaCoders

struct PESOptionalHeaderTests {
  @Test
  func encodeEmptyHeader() async throws {
    let sut = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .none
    )

    #expect(sut.bytes == [0b1000_0000, 0b0000_0000, 0b0000_0000])
  }

  @Test
  func encodePts() async throws {
    let sut = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .pts(
        .init(value: 123_456_789, timescale: 90000)
      )
    )

    #expect(
      sut.bytes == [
        0b1000_0000,
        0b1000_0000,
        0b0000_0101,

        0b0010_0001,
        0b0001_1101,
        0b0110_1111,
        0b1001_1010,
        0b0010_1011,
      ])
  }

  @Test
  func encodePtsAndDts() async throws {
    let sut = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .ptsAndDts(
        pts: .init(value: 123_456_789, timescale: 90000),
        dts: .init(value: 42, timescale: 90000)
      )
    )

    #expect(
      sut.bytes == [
        0b1000_0000,
        0b1100_0000,
        0b0000_1010,
        //PTS
        0b0011_0001,
        0b0001_1101,
        0b0110_1111,
        0b1001_1010,
        0b0010_1011,
        //DTS
        0b0001_0001,
        0b0000_0000,
        0b0000_0001,
        0b0000_0000,
        0b0101_0101,
      ]
    )
  }

  @Test
  func encodeAndDecode() async throws {
    let src = PESHeaderExtension(
      scramblingControl: .notScrambling,
      ptsAndDts: .ptsAndDts(
        pts: .init(value: 123_456_789, timescale: 90000),
        dts: .init(value: 42, timescale: 90000)
      )
    )

    let sut = try PESHeaderExtension(bytes: src.bytes)

    #expect(sut == src)
  }

  @Test
  func detectInsufficientDataBytes() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1000_0000, 0b0000_0101,
      0b0010_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010,
    ]

    #expect(throws: AVMediaCodersError.invalidPES(.headerDataTooShort)) {
      try PESHeaderExtension(bytes: bytes)
    }
  }

  @Test
  func detectConflictingPtsData() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1000_0000, 0b0000_0101,
      0b0011_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
    ]

    #expect(throws: AVMediaCodersError.invalidPES(.conflictingPtsDtsFlag)) {
      try PESHeaderExtension(bytes: bytes)
    }
  }

  @Test
  func detectConflictingPtsInPtsDtsData() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1100_0000, 0b0000_1010,
      0b0010_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
      0b0001_0001, 0b0000_0000, 0b0000_0001, 0b0000_0000, 0b0101_0101,
    ]

    #expect(throws: AVMediaCodersError.invalidPES(.conflictingPtsDtsFlag)) {
      try PESHeaderExtension(bytes: bytes)
    }
  }

  @Test
  func detectConflictingDtsInPtsDtsData() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1100_0000, 0b0000_1010,
      0b0011_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
      0b0010_0001, 0b0000_0000, 0b0000_0001, 0b0000_0000, 0b0101_0101,
    ]

    #expect(throws: AVMediaCodersError.invalidPES(.conflictingPtsDtsFlag)) {
      try PESHeaderExtension(bytes: bytes)
    }
  }

  @Test
  func detectWrongLengthWithPtsDtsData() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1100_0000, 0b0000_0101,
      0b0011_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
      0b0001_0001, 0b0000_0000, 0b0000_0001, 0b0000_0000, 0b0101_0101,
    ]

    #expect(throws: AVMediaCodersError.bufferTooShort) {
      try PESHeaderExtension(bytes: bytes)
    }
  }

  @Test 
  func retainOnlyRelevantBytes() async throws {
    let bytes: [UInt8] = [
      0b1000_0000, 0b1100_0000, 0b0000_1010,
      0b0011_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
      0b0001_0001, 0b0000_0000, 0b0000_0001, 0b0000_0000, 0b0101_0101,
      0b0001_0000, 0b1100_0000, 0b0000_1010,
    ]

    let sut = try PESHeaderExtension(bytes: bytes)

    #expect(
      sut.bytes == [
        0b1000_0000, 0b1100_0000, 0b0000_1010,
        0b0011_0001, 0b0001_1101, 0b0110_1111, 0b1001_1010, 0b0010_1011,
        0b0001_0001, 0b0000_0000, 0b0000_0001, 0b0000_0000, 0b0101_0101,
      ]
    )
  }
}

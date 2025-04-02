import Testing

@testable import AVMediaCoders

struct TSAdaptationFieldTests {
  @Test
  func encodeSimpleAdaptationFields() async throws {
    let sut = TSAdaptationField(remainingDataLength: 300)

    let bytes = sut.bytes

    #expect(bytes == [0x01, 0x00])
  }

  @Test
  func encodeFieldsWithPCRandOPCE() async throws {
    let sut = TSAdaptationField(
      remainingDataLength: 300,
      pcr: TSClockReference(0x1FFFF_FFFF),
      opcr: TSClockReference(0, ext: 0x1FF),
      randomAccessIndicator: true
    )

    let bytes = sut.bytes

    #expect(
      bytes == [
        0x0D, 0x58,
        0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
      ]
    )
  }

  @Test(
    arguments: [
      TSAdaptationField(remainingDataLength: 300),
      TSAdaptationField(
        remainingDataLength: 300,
        pcr: TSClockReference(0x1FFFF_FFFF),
        opcr: TSClockReference(0, ext: 0x1FF),
        randomAccessIndicator: true
      ),
      TSAdaptationField(
        remainingDataLength: 300,
        pcr: TSClockReference(0x1FFFF_FFFF),
        opcr: nil,
        randomAccessIndicator: false
      ),
    ]
  )
  func encodeAndDecode(_ src: TSAdaptationField) async throws {
    let bytes = src.bytes

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func keepJustRelevantBytes() async throws {
    let bytes: [UInt8] = [
      0x0D, 0x58,
      0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
      0x00, 0x00, 0x01,
    ]

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(
      sut.bytes == [
        0x0D, 0x58,
        0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
      ]
    )
  }

  @Test
  func detectInsufficientPayloadBuffer() async throws {
    let bytes: [UInt8] = [
      0x0D, 0x58,
      0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01,
    ]

    #expect(throws: AVMediaCodersError.bufferTooShort) {
      try TSAdaptationField(bytes: bytes)
    }
  }

  @Test
  func keepSpecifiedSizeEventNotHandledForNow() async throws {
    let bytes: [UInt8] = [
      0x10, 0x5A,
      0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
      0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
      0x02, 0x3A, 0x80,
    ]

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(
      sut.bytes == [
        0x10, 0x5A,
        0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
        0x02, 0x3A, 0x80,
      ]
    )
  }

  @Test
  func parseSpliceCountdown() async throws {
    let bytes: [UInt8] = [
      0x07, 0x14,
      0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
      0x36,
    ]

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(sut.spliceCountdown == 0x36)
  }

  @Test
  func parsePrivateData() async throws {
    let bytes: [UInt8] = [
      0x09, 0x16,
      0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
      0x36,
      0x02, 0x3A, 0x80,
    ]

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(sut.transportPrivateData == [0x3A, 0x80])
  }

  @Test
  func inferMinStuffingBytes() async throws {
    let sut = TSAdaptationField(remainingDataLength: Int(TSAdaptationField.maximumLength))

    let bytes = sut.bytes

    #expect(bytes == [0x01, 0x00])
  }

  @Test
  func inferMaxStuffingBytes() async throws {
    let sut = TSAdaptationField(remainingDataLength: 0)

    let bytes = sut.bytes

    #expect(bytes == [0xB7, 0x00] + Array(repeating: 0xFF, count: 182))
  }

  @Test(
    arguments: [
      TSAdaptationField(remainingDataLength: 10),
      TSAdaptationField(remainingDataLength: 0),
      TSAdaptationField(remainingDataLength: Int(TSAdaptationField.minimumLength)),
      TSAdaptationField(remainingDataLength: Int(TSAdaptationField.maximumLength)),
    ]
  )
  func encodeDecodeStuffingBytes(_ src: TSAdaptationField) async throws {
    let bytes = src.bytes

    let sut = try TSAdaptationField(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func encodeAdaptationFieldDataWithStuffing() async throws {
    let sut = TSAdaptationField(
      remainingDataLength: 0,
      pcr: TSClockReference(0x1FFFF_FFFF),
      opcr: TSClockReference(0, ext: 0x1FF),
      randomAccessIndicator: true
    )

    let bytes = sut.bytes

    #expect(
      bytes == [
        0xB7, 0x58,
        0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0xFF,
      ] + Array(repeating: 0xFF, count: 170)
    )

  }
}

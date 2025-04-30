import Testing

@testable import AVMediaCoders

struct TSHeaderTests {
  @Test
  func encodeSimpleHeader() async throws {
    let sut = TSHeader(
      isStartOfPayload: true,
      PID: .programAssociationTable,
      adaptationFieldControl: .payloadOnly,
      continuityCounter: 0
    )

    let bytes = sut.bytes

    #expect(bytes == [0b0100_0111, 0b0100_0000, 0b0000_0000, 0b0001_0000])
  }

  @Test(
    arguments: [
      TSHeader(
        isStartOfPayload: true,
        PID: .programAssociationTable,
        adaptationFieldControl: .payloadOnly,
        continuityCounter: 0
      ),
      TSHeader(
        isStartOfPayload: false,
        PID: .nullPacket,
        adaptationFieldControl: .adaptationFieldOnly,
        continuityCounter: 0x0f
      ),
      TSHeader(
        isStartOfPayload: false,
        PID: .nullPacket,
        adaptationFieldControl: .adaptationFieldAndPayload,
        continuityCounter: 0x0f
      ),
    ]
  )
  func encodeAndDecode(_ src: TSHeader) async throws {
    let bytes = src.bytes
    let sut = try TSHeader(bytes: bytes)

    #expect(src == sut)
  }

  @Test
  func rejectShortBuffer() async throws {
    let bytes: [UInt8] = [0b0100_0111, 0b0100_0000, 0b0000_0000]

    #expect(
      throws: AVMediaCodersError.bufferTooShort
    ) {
      try TSHeader(bytes: bytes)
    }
  }

  @Test
  func rejectInvalidSyncByte() async throws {
    let bytes: [UInt8] = [0b0100_0110, 0b0100_0000, 0b0000_0000, 0b0001_0000]

    #expect(
      throws: AVMediaCodersError.invalidTS(.invalidSyncByte)
    ) {
      try TSHeader(bytes: bytes)
    }
  }
}

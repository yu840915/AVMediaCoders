import Testing

@testable import MPEGTransport

struct TSProgramElementInfoTests {
  @Test
  func initialization() async throws {
    let sut = TSProgramElementInfo(
      streamType: .videoHEVC,
      elementaryPID: .dataStream(streamID: 1),
      ESInfo: [0xFF, 0x42]
    )

    #expect(sut.streamType == .videoHEVC)
    #expect(sut.elementaryPID == .dataStream(streamID: 1))
    #expect(sut.ESInfo == [0xFF, 0x42])
    #expect(sut.ESInfo.count == 2)
  }

  @Test
  func encode() async throws {
    let sut = TSProgramElementInfo(
      streamType: .videoHEVC,
      elementaryPID: .dataStream(streamID: 1),
      ESInfo: [0xFF, 0x42]
    )

    let bytes = sut.bytes

    #expect(
      bytes == [
        0x24,  // hevc
        0x00, 0x21,  // elementaryPID
        0x00, 0x02,  // ESInfoLength
        0xFF, 0x42,  // ESInfo
      ]
    )
  }

  @Test
  func encodeAndDecode() async throws {
    let src = TSProgramElementInfo(
      streamType: .videoHEVC,
      elementaryPID: .dataStream(streamID: 1),
      ESInfo: [0xFF, 0x42]
    )
    let bytes = src.bytes

    let sut = try TSProgramElementInfo(bytes: bytes)

    #expect(sut == src)
  }

  @Test(arguments: [
    [0x24, 0x00, 0x21, 0x00],  //truncated meta
    [0x24, 0x00, 0x21, 0x00, 0x02, 0xFF],  // truncated info
  ])
  func detectBufferTooShort(_ bytes: [UInt8]) async throws {
    #expect(throws: MPEGTransportError.bufferTooShort) {
      _ = try TSProgramElementInfo(bytes: bytes)
    }
  }

  @Test
  func keepJustEnoughtBufferLength() async throws {
    let bytes: [UInt8] = [
      0x24, 0x00, 0x21, 0x00, 0x02, 0xFF, 0x42,
      0x24,  //Start of next element
    ]

    let sut = try TSProgramElementInfo(bytes: bytes)

    #expect(sut.bytes == [0x24, 0x00, 0x21, 0x00, 0x02, 0xFF, 0x42])
  }
}

import Testing

@testable import AVMediaCoders

struct PESPacketTests {
  @Test
  func encodePaddingStream() async throws {
    let sut = PESPacket(
      streamType: .paddingStream,
      payload: [0xff, 0xff, 0xff]
    )

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xBE, 0x00, 0x03,
        0xff, 0xff, 0xff,
      ]
    )
  }

  @Test
  func encodeVideoStream() async throws {
    let sut = PESPacket(
      streamType: .video(
        streamID: 1,
        extension: PESHeaderExtension(
          scramblingControl: .notScrambling,
          isOriginal: false,
          ptsAndDts: .pts(
            .init(value: 123_456_789, timescale: 90000)
          )
        )
      ),
      payload: [0xff, 0xff, 0xff]
    )

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xE1, 0x00, 0x0B,
        0x80, 0x80, 0x05,
        0x21, 0x1D, 0x6F, 0x9A, 0x2B,
        0xff, 0xff, 0xff,
      ]
    )
  }

  @Test(
    arguments: [
      PESPacket(streamType: .privateStream2),
      PESPacket(
        streamType: .paddingStream,
        payload: [0xff, 0xff, 0xff]
      ),
      PESPacket(
        streamType: .video(
          streamID: 3,
          extension: PESHeaderExtension(
            scramblingControl: .notScrambling,
            isOriginal: true,
            ptsAndDts: .ptsAndDts(
              pts: .init(seconds: 100, preferredTimescale: 90000),
              dts: .init(seconds: 98, preferredTimescale: 90000)
            )
          )
        ),
        payload: [0xff, 0xff, 0xff]
      ),
    ]
  )
  func encodeAndDecode(_ src: PESPacket) async throws {
    let sut = try PESPacket(bytes: src.bytes)

    #expect(sut == src)
  }

  @Test
  func detectInsufficientPayloadBuffer() async throws {
    let bytes: [UInt8] = [
      0x00, 0x00, 0x01, 0xE1, 0x00, 0x0B,
      0x80, 0x80, 0x05,
      0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      0xff, 0xff,
    ]

    #expect(throws: AVMediaCodersError.bufferTooShort) {
      try PESPacket(bytes: bytes)
    }
  }

  @Test
  func retainOnlyRelevantBytes() async throws {
    let bytes: [UInt8] = [
      0x00, 0x00, 0x01, 0xE1, 0x00, 0x0B,
      0x80, 0x80, 0x05,
      0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      0xff, 0xff, 0xff, 0xff,
    ]

    let sut = try PESPacket(bytes: bytes)

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xE1, 0x00, 0x0B,
        0x80, 0x80, 0x05,
        0x21, 0x1D, 0x6F, 0x9A, 0x2B,
        0xff, 0xff, 0xff,
      ]
    )
  }
}

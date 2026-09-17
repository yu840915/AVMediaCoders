import Testing

@testable import MPEGTransport

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
            .init(value: 123_456_789, scale: 90000)
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
              pts: .init(value: 100, scale: 90000),
              dts: .init(value: 98, scale: 90000)
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

    #expect(throws: MPEGTransportError.bufferTooShort) {
      try PESPacket(bytes: bytes)
    }
  }

  @Test
  func encodeOversizedVideoPayloadAsUnbounded() async throws {
    let payload = [UInt8](repeating: 0xAB, count: 200_000)
    let sut = PESPacket(
      streamType: .video(
        streamID: 0,
        extension: PESHeaderExtension(
          ptsAndDts: .pts(.init(value: 123_456_789, scale: 90000))
        )
      ),
      payload: payload
    )

    #expect(Array(sut.bytes[4...5]) == [0x00, 0x00])
    #expect(sut.payload == payload)
  }

  @Test
  func decodeUnboundedPayload() async throws {
    let payload = [UInt8](repeating: 0xAB, count: 200_000)
    let src = PESPacket(
      streamType: .video(
        streamID: 0,
        extension: PESHeaderExtension(
          ptsAndDts: .ptsAndDts(
            pts: .init(value: 100, scale: 90000),
            dts: .init(value: 98, scale: 90000)
          )
        )
      ),
      payload: payload
    )

    let sut = try PESPacket(bytes: src.bytes)

    #expect(sut == src)
    #expect(sut.payload.count == payload.count)
  }

  @Test
  func encodeAtUnboundedBoundary() async throws {
    let ext = PESHeaderExtension(
      ptsAndDts: .pts(.init(value: 100, scale: 90000))
    )
    let exactPayload = [UInt8](repeating: 0x01, count: 0xFFFF - ext.bytes.count)

    let bounded = PESPacket(
      streamType: .video(streamID: 0, extension: ext),
      payload: exactPayload
    )
    let unbounded = PESPacket(
      streamType: .video(streamID: 0, extension: ext),
      payload: exactPayload + [0x01]
    )

    #expect(Array(bounded.bytes[4...5]) == [0xFF, 0xFF])
    #expect(try PESPacket(bytes: bounded.bytes) == bounded)
    #expect(Array(unbounded.bytes[4...5]) == [0x00, 0x00])
    #expect(try PESPacket(bytes: unbounded.bytes) == unbounded)
  }

  @Test
  func detectPacketLengthShorterThanHeaderExtension() async throws {
    let bytes: [UInt8] = [
      0x00, 0x00, 0x01, 0xE1, 0x00, 0x01,
      0x80, 0x80, 0x05,
      0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      0xff, 0xff, 0xff,
    ]

    #expect(throws: MPEGTransportError.invalidPES(.invalidPacketLength)) {
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

import Testing

@testable import MPEGTransport

struct PESHeaderTests {
  @Test
  func encodeEmptyPaddingStream() async throws {
    let sut = PESHeader(
      type: .paddingStream,
      payloadLength: 0
    )

    #expect(sut.bytes == [0x00, 0x00, 0x01, 0xBE, 0x00, 0x00])
  }

  @Test
  func encodeNonEmptyPaddingStream() async throws {
    let sut = PESHeader(
      type: .paddingStream,
      payloadLength: 42
    )

    #expect(sut.bytes == [0x00, 0x00, 0x01, 0xBE, 0x00, 0x2A])
  }

  @Test
  func encodePrivateStream() async throws {
    let sut = PESHeader(
      type: .privateStream2,
      payloadLength: 42
    )

    #expect(sut.bytes == [0x00, 0x00, 0x01, 0xBF, 0x00, 0x2A])
  }

  @Test
  func encodePrivateStream1() async throws {
    let ext = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .none
    )
    let sut = PESHeader(
      type: .privateStream1(extension: ext),
      payloadLength: 42
    )

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xBD, 0x00, 0x2D,
        0x80, 0x00, 0x00,
      ]
    )
  }

  @Test
  func encodeAudioStream() async throws {
    let ext = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .pts(
        .init(value: 123_456_789, scale: 90000)
      )
    )

    let sut = PESHeader(
      type: .audio(streamID: 1, extension: ext),
      payloadLength: 42
    )

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xC1, 0x00, 0x32,
        0x80, 0x80, 0x05,
        0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      ]
    )
  }

  @Test
  func encodeVideoStream() async throws {
    let ext = PESHeaderExtension(
      scramblingControl: .notScrambling,
      isOriginal: false,
      ptsAndDts: .pts(
        .init(value: 123_456_789, scale: 90000)
      )
    )

    let sut = PESHeader(
      type: .video(streamID: 1, extension: ext),
      payloadLength: 42
    )

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xE1, 0x00, 0x32,
        0x80, 0x80, 0x05,
        0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      ]
    )
  }

  @Test(
    arguments: [
      PESHeader(type: .paddingStream, payloadLength: 0),
      PESHeader(type: .paddingStream, payloadLength: 42),
      PESHeader(type: .privateStream2, payloadLength: 42),
      PESHeader(
        type: .video(
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
        payloadLength: 42
      ),
    ]
  )
  func encodeAndDecode(_ src: PESHeader) async throws {
    let bytes = src.bytes

    let sut = try PESHeader(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func rejectInvalidAudioStreamID() async throws {
    #expect(throws: MPEGTransportError.invalidPES(.invalidStreamID)) {
      try PESHeader.StreamType(
        audioStreamID: 0b0010_0000,
        extension: PESHeaderExtension(scramblingControl: .notScrambling, ptsAndDts: .none)
      )
    }
  }

  @Test
  func rejectInvalidVideoStreamID() async throws {
    #expect(throws: MPEGTransportError.invalidPES(.invalidStreamID)) {
      try PESHeader.StreamType(
        videoStreamID: 0b0001_0000,
        extension: PESHeaderExtension(scramblingControl: .notScrambling, ptsAndDts: .none)
      )
    }
  }

  @Test
  func rejectInvalidStartCode() async throws {
    let bytes: [UInt8] = [0x00, 0x00, 0x02, 0xBE, 0x00, 0x00]

    #expect(throws: MPEGTransportError.invalidPES(.invalidStartCode)) {
      try PESHeader(bytes: bytes)
    }
  }

  @Test
  func rejectBufferTooShort() async throws {
    let bytes: [UInt8] = [0x00, 0x00, 0x01, 0xBE, 0x00]

    #expect(throws: MPEGTransportError.bufferTooShort) {
      try PESHeader(bytes: bytes)
    }
  }

  @Test
  func keepOnlyRelevantBytes() async throws {
    let bytes: [UInt8] = [
      0x00, 0x00, 0x01, 0xE1, 0x00, 0x32,
      0x80, 0x80, 0x05,
      0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      0x00, 0x00, 0x01, 0xE1, 0x00, 0x32,
    ]

    let sut = try PESHeader(bytes: bytes)

    #expect(
      sut.bytes == [
        0x00, 0x00, 0x01, 0xE1, 0x00, 0x32,
        0x80, 0x80, 0x05,
        0x21, 0x1D, 0x6F, 0x9A, 0x2B,
      ]
    )
  }
}

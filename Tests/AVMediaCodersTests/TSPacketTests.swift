import Testing

@testable import AVMediaCoders

struct TSPacketTests {
  @Test
  func simpleInitialization() async throws {
    let sut = TSPacket(
      pid: 0xFF, continuityCounter: 0x2, data: [0x42]
    )

    #expect(sut.header.pid == 0xFF)
    #expect(sut.header.continuityCounter == 0x2)
    guard case let .both(field, payload) = sut.payload else {
      throw TestError.unexpectedValue
    }
    #expect(payload == [0x42])
    #expect(field.length == 182)  //184 - {len byte} - {data len}
    #expect(sut.bytes.count == 188)
  }

  @Test
  func allPadding() async throws {
    let sut = TSPacket(pid: 0xFF, continuityCounter: 0x2)

    #expect(sut.header.pid == 0xFF)
    #expect(sut.header.continuityCounter == 0x2)
    guard case let .adaptationField(field) = sut.payload else {
      throw TestError.unexpectedValue
    }
    #expect(field.length == 183)  //184 - {len byte}
    #expect(sut.bytes.count == 188)
  }

  @Test(arguments: [
    TSPacket(pid: 0xFF, continuityCounter: 0x2),
    TSPacket(pid: 0xFF, continuityCounter: 0x2, data: [0x42]),
  ])
  func encodeDecode(_ src: TSPacket) async throws {
    let bytes = src.bytes

    let sut = try TSPacket(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func detectInsufficientBuffer() async throws {
    let bytes = TSPacket(pid: 0xFF, continuityCounter: 0x2, data: [0x42]).bytes

    #expect(throws: AVMediaCodersError.bufferTooShort) {
      try TSPacket(bytes: Array(bytes[0..<bytes.count - 1]))
    }
  }

  @Test
  func retainOnlyRelevantBytes() async throws {
    let src = TSPacket(pid: 0xFF, continuityCounter: 0x2, data: [0x42])
    let bytes = src.bytes + [0x47]

    let sut = try TSPacket(bytes: bytes)

    #expect(sut == src)
  }

}

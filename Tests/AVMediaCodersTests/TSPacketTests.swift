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
}

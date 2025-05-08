import Testing

@testable import AVMediaCoders

struct TSDataPacketizerTests {
  @Test
  func packetizeMockIFrame() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataPacketizer(pid: pid)

    let input = [UInt8](repeating: 0xAA, count: 1000)

    let packets = sut.packetize(
      adaptationFieldConfiguration: .init(
        pcr: TSClockReference(0x1_FFFF_FFFF),
        opcr: nil,
        allowRandomAccess: true
      ),
      data: input
    )

    #expect(packets.count == 6)
    #expect(
      packets.map { $0.header.pid } == [
        pid.value, pid.value, pid.value, pid.value, pid.value, pid.value,
      ])
    #expect(
      packets.map { $0.header.isStartOfPayload } == [true, false, false, false, false, false]
    )
    #expect(
      packets.map { $0.header.adaptationFieldControl } == [
        .adaptationFieldAndPayload,
        .payloadOnly,
        .payloadOnly,
        .payloadOnly,
        .payloadOnly,
        .adaptationFieldAndPayload,
      ]
    )
    #expect(packets.map { $0.header.continuityCounter } == [0, 1, 2, 3, 4, 5])
  }

  @Test
  func continuityCounterRevolve() async throws {
    let sut = TSDataPacketizer(
      pid: .dataStream(streamID: 0x0),
      continuityCounter: 0x0D
    )

    let input = [UInt8](repeating: 0xAA, count: 1000)

    let packets = sut.packetize(
      adaptationFieldConfiguration: .init(
        pcr: TSClockReference(0x1_FFFF_FFFF),
        opcr: nil,
        allowRandomAccess: true
      ),
      data: input
    )

    #expect(packets.count == 6)
    #expect(
      packets.map { $0.header.isStartOfPayload } == [true, false, false, false, false, false]
    )
    #expect(packets.map { $0.header.continuityCounter } == [0x0D, 0x0E, 0x0F, 0x00, 0x01, 0x02])
  }

  @Test
  func packetizePadding() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataPacketizer(
      pid: pid,
      continuityCounter: 0x0D
    )

    let packets = sut.createPaddings(count: 3)

    #expect(packets.map { $0.header.continuityCounter } == [0x0D, 0x0D, 0x0D])
    #expect(packets.map { $0.header.pid } == [pid.value, pid.value, pid.value])
    #expect(packets.map { $0.payload.dataPayloadLength } == [0, 0, 0])
  }
}

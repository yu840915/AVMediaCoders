import Testing

@testable import AVMediaCoders

struct TSESDepacketizerTests {
  @Test
  func stashPacket() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)

    let output = await sut.feed([
      TSPacket(
        pid: pid.value,
        continuityCounter: 0,
        isStartOfPayload: true,
        adaptationFieldConfiguration: nil,
        data: [0xAA]
      )
    ])

    #expect(output.isEmpty)
    #expect((await sut.stashedPackets.count) == 1)
  }

  @Test
  func flush() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)

    _ = await sut.feed([
      TSPacket(
        pid: pid.value,
        continuityCounter: 0,
        isStartOfPayload: true,
        adaptationFieldConfiguration: nil,
        data: [0xAA]
      )
    ])
    let output = await sut.flush()

    #expect(output?.esData == [0xAA])
    #expect(await sut.stashedPackets.isEmpty)
  }

  @Test
  func flushOnNextStart() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)

    _ = await sut.feed(
      [
        TSPacket(
          pid: pid.value,
          continuityCounter: 0,
          isStartOfPayload: true,
          adaptationFieldConfiguration: nil,
          data: [0xAA]
        )
      ]
    )
    let output = await sut.feed(
      [
        TSPacket(
          pid: pid.value,
          continuityCounter: 1,
          isStartOfPayload: true,
          adaptationFieldConfiguration: nil,
          data: [0xAB]
        )
      ]
    )

    #expect(output.count == 1)
    #expect(output[0].esData == [0xAA])
  }

  @Test
  func skipPacketForMismatchingPID() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)

    _ = await sut.feed(
      [
        TSPacket(
          pid: pid.value + 1,
          continuityCounter: 1,
          isStartOfPayload: true,
          adaptationFieldConfiguration: nil,
          data: [0xAB]
        )
      ]
    )

    #expect(await sut.stashedPackets.isEmpty)
  }

  @Test
  func skipPacketsIfNotStarted() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)

    _ = await sut.feed(
      [
        TSPacket(
          pid: pid.value,
          continuityCounter: 1,
          isStartOfPayload: false,
          adaptationFieldConfiguration: nil,
          data: [0xAB]
        )
      ]
    )

    #expect(await sut.stashedPackets.isEmpty)
  }

  @Test
  func packetizeDepacketize() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSESDepacketizer(pid: pid)
    let packetizer = TSESPacketizer(pid: pid)

    let input = [UInt8](repeating: 0xAA, count: 1000)

    let packets = await packetizer.packetize(
      adaptationFieldConfiguration: .init(
        pcr: TSClockReference(0x1_FFFF_FFFF),
        opcr: nil,
        allowRandomAccess: true
      ),
      esData: input
    )

    _ = await sut.feed(packets)
    let output = await sut.flush()

    #expect(output?.esData == input)
    #expect(output?.adaptationField?.pcr == TSClockReference(0x1_FFFF_FFFF))
    #expect(output?.adaptationField?.randomAccessIndicator == true)
  }
}

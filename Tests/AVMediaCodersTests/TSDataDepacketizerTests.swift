import Testing

@testable import AVMediaCoders

struct TSDataDepacketizerTests {
  @Test
  func stashPacket() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)

    let output = sut.feed([
      TSPacket(
        PID: pid,
        continuityCounter: 0,
        isStartOfPayload: true,
        adaptationFieldConfiguration: nil,
        data: [0xAA]
      )
    ])

    #expect(output.isEmpty)
    #expect((sut.stashedPackets.count) == 1)
  }

  @Test
  func flush() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)

    _ = sut.feed([
      TSPacket(
        PID: pid,
        continuityCounter: 0,
        isStartOfPayload: true,
        adaptationFieldConfiguration: nil,
        data: [0xAA]
      )
    ])
    let output = sut.flush()

    #expect(output?.esData == [0xAA])
    #expect(sut.stashedPackets.isEmpty)
  }

  @Test
  func flushOnNextStart() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)

    _ = sut.feed(
      [
        TSPacket(
          PID: pid,
          continuityCounter: 0,
          isStartOfPayload: true,
          adaptationFieldConfiguration: nil,
          data: [0xAA]
        )
      ]
    )
    let output = sut.feed(
      [
        TSPacket(
          PID: pid,
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
    let sut = TSDataDepacketizer(pid: pid)

    _ = sut.feed(
      [
        TSPacket(
          PID: .dataStream(streamID: 0x1),
          continuityCounter: 1,
          isStartOfPayload: true,
          adaptationFieldConfiguration: nil,
          data: [0xAB]
        )
      ]
    )

    #expect(sut.stashedPackets.isEmpty)
  }

  @Test
  func skipPacketsIfNotStarted() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)

    _ = sut.feed(
      [
        TSPacket(
          PID: pid,
          continuityCounter: 1,
          isStartOfPayload: false,
          adaptationFieldConfiguration: nil,
          data: [0xAB]
        )
      ]
    )

    #expect(sut.stashedPackets.isEmpty)
  }

  @Test
  func packetizeDepacketize() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)
    let packetizer = TSDataPacketizer(pid: pid)

    let input = [UInt8](repeating: 0xAA, count: 1000)

    let packets = packetizer.packetize(
      adaptationFieldConfiguration: .init(
        pcr: TSClockReference(0x1_FFFF_FFFF),
        opcr: nil,
        allowRandomAccess: true
      ),
      data: input
    )

    _ = sut.feed(packets)
    let output = sut.flush()

    #expect(output?.esData == input)
    #expect(output?.adaptationField?.pcr == TSClockReference(0x1_FFFF_FFFF))
    #expect(output?.adaptationField?.randomAccessIndicator == true)
  }

  @Test
  func serialDepacketizing() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)
    let packetizer = TSDataPacketizer(pid: pid, continuityCounter: 0x0E)

    let input = [UInt8](repeating: 0xAA, count: 1000)
    let input2 = [UInt8](repeating: 0xAB, count: 280)
    let input3 = [UInt8](repeating: 0xAA, count: 255)

    let packets =
      packetizer.packetize(
        adaptationFieldConfiguration: .init(
          pcr: TSClockReference(0x1),
          opcr: nil,
          allowRandomAccess: true
        ),
        data: input
      ) + packetizer.createPaddings(count: 2)
      + packetizer.packetize(
        adaptationFieldConfiguration: .init(
          pcr: TSClockReference(0x2),
          opcr: nil,
          allowRandomAccess: false
        ),
        data: input2
      ) + packetizer.createPaddings(count: 12)
      + packetizer.packetize(
        adaptationFieldConfiguration: .init(
          pcr: TSClockReference(0x3),
          opcr: nil,
          allowRandomAccess: false
        ),
        data: input3
      )

    let outputs = sut.feed(packets)

    #expect(outputs.map { $0.esData } == [input, input2])
    #expect(
      outputs.map { $0.adaptationField?.pcr } == [TSClockReference(0x1), TSClockReference(0x2)]
    )
    #expect(
      outputs.map { $0.adaptationField?.randomAccessIndicator } == [true, false]
    )
  }

  @Test
  func checkContinuity() async throws {
    let pid = TSPID.dataStream(streamID: 0x0)
    let sut = TSDataDepacketizer(pid: pid)
    let packetizer = TSDataPacketizer(pid: pid, continuityCounter: 0x0E)

    let input = [UInt8](repeating: 0xAA, count: 1000)

    let packets =
      packetizer.packetize(
        adaptationFieldConfiguration: .init(
          pcr: TSClockReference(0x1),
          opcr: nil,
          allowRandomAccess: true
        ),
        data: input
      ).filter { $0.header.continuityCounter != 0x02 }
      + packetizer.createPaddings(count: 1)

    let outputs = sut.feed(Array(packets))

    #expect(outputs.isEmpty)
  }

}

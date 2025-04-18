import Testing

@testable import AVMediaCoders

struct TSProgramAssociationTableTests {
  @Test
  func initValue() async throws {
    let sut = TSProgramAssociationTable(
      versionNumber: 0x01,
      programs: [
        1: .dataStream(streamID: 0x01),
        2: .dataStream(streamID: 0x04),
      ]
    )

    #expect(sut.versionNumber == 0x01)
    #expect(
      sut.programs == [
        1: .dataStream(streamID: 0x01),
        2: .dataStream(streamID: 0x04),
      ]
    )
  }

  @Test
  func updateAndIncrementVersion() async throws {
    var sut = TSProgramAssociationTable(versionNumber: 0x01)

    sut.update(
      {
        $0[1] = .dataStream(streamID: 0x01)
        $0[2] = .dataStream(streamID: 0x04)
      }
    )

    #expect(sut.versionNumber == 0x02)
    #expect(
      sut.programs == [
        1: .dataStream(streamID: 0x01),
        2: .dataStream(streamID: 0x04),
      ]
    )
  }

  @Test
  func doNotIncrementIfNotChanged() async throws {
    var sut = TSProgramAssociationTable(
      versionNumber: 0x0001,
      programs: [
        1: .dataStream(streamID: 0x01),
        2: .dataStream(streamID: 0x04),
      ]
    )

    sut.update(
      {
        $0[1] = .dataStream(streamID: 0x01)
        $0[2] = .dataStream(streamID: 0x04)
      }
    )

    #expect(sut.versionNumber == 0x0001)
    #expect(
      sut.programs == [
        1: .dataStream(streamID: 0x01),
        2: .dataStream(streamID: 0x04),
      ]
    )
  }

  @Test
  func doNotOverflowVersion() async throws {
    var sut = TSProgramAssociationTable(versionNumber: 0x1F)

    sut.update(
      {
        $0[1] = .dataStream(streamID: 0x01)
        $0[2] = .dataStream(streamID: 0x04)
      }
    )

    #expect(sut.versionNumber == 0x00)
  }

}

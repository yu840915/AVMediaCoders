import Testing

@testable import AVMediaCoders

struct TSProgramMapTableTests {
  @Test
  func initValue() async throws {
    let sut = TSProgramMapTable(programNumber: 1)

    #expect(sut.programNumber == 1)
    #expect(sut.versionNumber == 0)
    #expect(sut.PCRPID == .dataStream(streamID: 0))
    #expect(sut.programInfo == [])
    #expect(sut.programElementInfos == [])
  }

  @Test
  func updateProgramInfoAndIncrementVersion() async throws {
    var sut = TSProgramMapTable(programNumber: 1)

    sut.update {
      $0.programInfo.append(0x01)
    }

    #expect(sut.versionNumber == 1)
    #expect(sut.programInfo == [0x01])
  }

  @Test
  func updatePCRPIDAndIncrementVersion() async throws {
    var sut = TSProgramMapTable(programNumber: 1)

    sut.update {
      $0.PCRPID = .dataStream(streamID: 0x01)
    }

    #expect(sut.versionNumber == 1)
    #expect(sut.PCRPID == .dataStream(streamID: 0x01))
  }

  @Test
  func updateProgramElementInfosAndIncrementVersion() async throws {
    var sut = TSProgramMapTable(programNumber: 1)

    sut.update {
      $0.PCRPID = .dataStream(streamID: 0x01)
      $0.programElementInfos.append(
        TSProgramElementInfo(
          streamType: .videoHEVC,
          elementaryPID: .dataStream(streamID: 0x01),
          ESInfo: []
        )
      )
    }

    #expect(sut.versionNumber == 1)
    #expect(
      sut.programElementInfos == [
        TSProgramElementInfo(
          streamType: .videoHEVC,
          elementaryPID: .dataStream(streamID: 0x01),
          ESInfo: []
        )
      ]
    )
  }

  @Test
  func updateAndIncrementVersion() async throws {
    var sut = TSProgramMapTable(programNumber: 1)

    sut.update {
      $0.PCRPID = .dataStream(streamID: 0x01)
      $0.programInfo.append(0x01)
      $0.programElementInfos.append(
        TSProgramElementInfo(
          streamType: .videoHEVC,
          elementaryPID: .dataStream(streamID: 0x01),
          ESInfo: []
        )
      )
    }

    #expect(
      sut
        == TSProgramMapTable(
          programNumber: 1,
          versionNumber: 1,
          PCRPID: .dataStream(streamID: 0x01),
          programInfo: [0x01],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 0x01),
              ESInfo: []
            )
          ]
        )
    )
  }

  @Test
  func doNotIncrementIfNotChanged() async throws {
    var sut = TSProgramMapTable(programNumber: 1)

    sut.update {
      $0.programInfo.removeAll()
    }

    #expect(sut.versionNumber == 0)
  }

  @Test
  func doNotOverflowVersion() async throws {
    var sut = TSProgramMapTable(
      programNumber: 1,
      versionNumber: 0x1F,
      programInfo: [0x42]
    )

    sut.update {
      $0.programInfo.removeAll()
    }

    #expect(
      sut
        == TSProgramMapTable(
          programNumber: 1,
          versionNumber: 0x00,
          programInfo: []
        )
    )
  }

  @Test
  func convertToSection() async throws {
    let sut = TSProgramMapTable(
      programNumber: 1,
      versionNumber: 2,
      PCRPID: .dataStream(streamID: 0x01),
      programInfo: [0x01],
      programElementInfos: [
        TSProgramElementInfo(
          streamType: .videoHEVC,
          elementaryPID: .dataStream(streamID: 0x01),
          ESInfo: []
        )
      ]
    )

    let section = try sut.convertToSection()

    #expect(
      try section
        == TSProgramMapSection(
          programNumber: 1,
          versionNumber: 2,
          PCRPID: .dataStream(streamID: 0x01),
          programInfo: [0x01],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 0x01),
              ESInfo: []
            )
          ]
        )
    )
  }

  @Test
  func initWithSection() async throws {
    let sut = TSProgramMapTable(
      section: try TSProgramMapSection(
        programNumber: 1,
        versionNumber: 2,
        PCRPID: .dataStream(streamID: 0x01),
        programInfo: [0x01],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: .dataStream(streamID: 0x01),
            ESInfo: []
          )
        ]
      )
    )

    #expect(
      sut
        == TSProgramMapTable(
          programNumber: 1,
          versionNumber: 2,
          PCRPID: .dataStream(streamID: 0x01),
          programInfo: [0x01],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 0x01),
              ESInfo: []
            )
          ]
        )
    )
  }
}

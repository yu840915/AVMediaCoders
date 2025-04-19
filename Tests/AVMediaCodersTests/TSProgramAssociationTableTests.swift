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

  @Test
  func convertSmallTableToSections() async throws {
    let sut = TSProgramAssociationTable(
      versionNumber: 0,
      programs: [
        1: .dataStream(streamID: 0),
        2: .dataStream(streamID: 1),
      ]
    )

    let sections = sut.convertToSections()

    #expect(
      sections == [
        try! TSProgramAssociationSection(
          versionNumber: 0, sectionNumber: 0, lastSectionNumber: 0,
          programMapPIDs: [
            .init(programNumber: 1, PID: .dataStream(streamID: 0)),
            .init(programNumber: 2, PID: .dataStream(streamID: 1)),
          ]
        )
      ]
    )
  }

  @Test
  func mergeSectionToTable() async throws {
    let sut = try TSProgramAssociationTable(
      sections: [
        TSProgramAssociationSection(
          versionNumber: 0, sectionNumber: 0, lastSectionNumber: 0,
          programMapPIDs: [
            .init(programNumber: 1, PID: .dataStream(streamID: 0)),
            .init(programNumber: 2, PID: .dataStream(streamID: 1)),
          ]
        )
      ]
    )

    #expect(
      sut
        == TSProgramAssociationTable(
          versionNumber: 0,
          programs: [
            1: .dataStream(streamID: 0),
            2: .dataStream(streamID: 1),
          ]
        )
    )
  }

  @Test
  func convertSmallTableBackAndFortchSections() async throws {
    let src = TSProgramAssociationTable(
      versionNumber: 0,
      programs: [
        1: .dataStream(streamID: 0),
        2: .dataStream(streamID: 1),
      ]
    )

    let sections = src.convertToSections()
    let dataList: [[UInt8]] = sections.map { $0.bytes }
    let restoredSections = try dataList.map {
      try TSProgramAssociationSection(bytes: $0)
    }
    let sut = try TSProgramAssociationTable(sections: restoredSections)

    #expect(sut == src)
  }

  @Test
  func convertLargeTableBackAndFortchSections() async throws {
    var programs: [UInt16: TSPID] = [:]
    for i: UInt16 in 0x0020...0x1FFE {
      let pid = try TSPID(rawValue: i)
      if case let .dataStream(streamID) = pid {
        programs[streamID] = pid
      }
    }

    let src = TSProgramAssociationTable(
      versionNumber: 0,
      programs: programs
    )

    let sections = src.convertToSections()
    let dataList: [[UInt8]] = sections.map { $0.bytes }

    let restoredSections = try dataList.map {
      try TSProgramAssociationSection(bytes: $0)
    }
    let sut = try TSProgramAssociationTable(sections: restoredSections)

    #expect(sections.count > 1)
    #expect(sut == src)
  }

  @Test
  func ensureVersionConsistency() async throws {
    let sections = [
      try TSProgramAssociationSection(
        versionNumber: 0, sectionNumber: 0, lastSectionNumber: 1,
        programMapPIDs: [
          .init(programNumber: 1, PID: .dataStream(streamID: 0))
        ]
      ),
      try TSProgramAssociationSection(
        versionNumber: 1, sectionNumber: 0, lastSectionNumber: 1,
        programMapPIDs: [
          .init(programNumber: 1, PID: .dataStream(streamID: 0)),
          .init(programNumber: 2, PID: .dataStream(streamID: 1)),
        ]
      ),
    ]

    #expect(throws: AVMediaCodersError.invalidTS(.inconsistentVersion)) {
      try TSProgramAssociationTable(sections: sections)
    }
  }

  @Test
  func rejectMissingSections() async throws {
    let sections = [
      try TSProgramAssociationSection(
        versionNumber: 0, sectionNumber: 0, lastSectionNumber: 0,
        programMapPIDs: [
          .init(programNumber: 1, PID: .dataStream(streamID: 0))
        ]
      ),
      try TSProgramAssociationSection(
        versionNumber: 0, sectionNumber: 1, lastSectionNumber: 2,
        programMapPIDs: [
          .init(programNumber: 2, PID: .dataStream(streamID: 1))
        ]
      ),
    ]

    #expect(throws: AVMediaCodersError.invalidTS(.invalidSectionNumber)) {
      try TSProgramAssociationTable(sections: sections)
    }
  }
}

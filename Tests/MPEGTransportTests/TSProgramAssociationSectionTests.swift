import Testing

@testable import MPEGTransport

struct TSProgramAssociationSectionTests {
  @Test(
    arguments: [
      ([TSProgramAssociationSection.TSPIDEntry], UInt8)
    ](
      [
        ([], UInt8(9)),
        (
          [.init(programNumber: 1, PID: .dataStream(streamID: 0))],
          UInt8(13)
        ),
        (
          [
            .init(programNumber: 1, PID: .dataStream(streamID: 0)),
            .init(programNumber: 2, PID: .dataStream(streamID: 0)),
          ],
          UInt8(17)
        ),
      ]
    )
  )
  func calculateSectionLengthOnInit(
    _ entries: [TSProgramAssociationSection.TSPIDEntry],
    _ length: UInt8
  )
    async throws
  {
    let sut = try TSProgramAssociationSection(
      versionNumber: 0,
      sectionNumber: 0,
      lastSectionNumber: 0,
      programMapPIDs: entries
    )

    #expect(
      sut.tableHeader.sectionLength == length
    )
  }

  @Test
  func correctHeader() async throws {
    let sut = try TSProgramAssociationSection(
      versionNumber: 0,
      sectionNumber: 0,
      lastSectionNumber: 1,
      programMapPIDs: [
        .init(programNumber: 1, PID: .dataStream(streamID: 0)),
        .init(programNumber: 2, PID: .dataStream(streamID: 1)),
      ]
    )

    #expect(
      try! sut.tableHeader
        == TSTableHeader(
          tableID: .programAssociationSection,
          sectionLength: 17
        )
    )
  }

  @Test
  func encodeEmpty() async throws {
    let sut = try TSProgramAssociationSection(
      transportStreamId: 0,
      versionNumber: 0,
      sectionNumber: 0,
      lastSectionNumber: 0,
      programMapPIDs: []
    )
    let bytes = sut.bytes

    #expect(
      bytes == [
        0x00, 0x80, 0x09,
        0x00, 0x00,  //transport stream ID
        0x01,  //reserved + version number + current next indicator true
        0x00,  //section number
        0x00,  //last section number
        0x87, 0x64, 0x9F, 0x03,  //CRC
      ]
    )
  }

  @Test
  func encodePrograms() async throws {
    let sut = try TSProgramAssociationSection(
      transportStreamId: 0,
      versionNumber: 0,
      sectionNumber: 0,
      lastSectionNumber: 0,
      programMapPIDs: [
        .init(programNumber: 1, PID: .dataStream(streamID: 0)),
        .init(programNumber: 2, PID: .dataStream(streamID: 1)),
      ]
    )

    let bytes = sut.bytes

    #expect(
      bytes == [
        0x00, 0x80, 0x11,
        0x00, 0x00,  //transport stream ID
        0x01,  //reserved + version number + current next indicator true
        0x00,  //section number
        0x00,  //last section number
        0x00, 0x01, 0x00, 0x20,  //program number + reserved + program map PID
        0x00, 0x02, 0x00, 0x21,  //program number + reserved + program map PID
        0x43, 0xB4, 0xB5, 0x51,  //CRC
      ]
    )
  }

  @Test(
    arguments: [
      try! TSProgramAssociationSection(
        transportStreamId: 0,
        versionNumber: 0,
        sectionNumber: 0,
        lastSectionNumber: 0,
        programMapPIDs: []
      ),
      try! TSProgramAssociationSection(
        transportStreamId: 0,
        versionNumber: 0,
        sectionNumber: 0,
        lastSectionNumber: 0,
        programMapPIDs: [
          .init(programNumber: 1, PID: .dataStream(streamID: 0)),
          .init(programNumber: 2, PID: .dataStream(streamID: 1)),
        ]
      ),
      try! TSProgramAssociationSection(
        transportStreamId: 5,
        versionNumber: 3,
        sectionNumber: 2,
        lastSectionNumber: 7,
        programMapPIDs: [
          .init(programNumber: 1, PID: .dataStream(streamID: 0)),
          .init(programNumber: 2, PID: .dataStream(streamID: 1)),
          .init(programNumber: 17, PID: .controlInformationTable),
        ]
      ),
    ]
  )
  func encodeDecode(_ src: TSProgramAssociationSection) async throws {
    let bytes = src.bytes

    let sut = try TSProgramAssociationSection(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func rejectInvalidCRC() async throws {
    let bytes: [UInt8] = [
      0x00, 0x80, 0x11, 0x00, 0x00, 0x01, 0x00, 0x00,
      0x00, 0x01, 0x00, 0x20, 0x00, 0x02, 0x00, 0x21,
      0x94, 0x50, 0xCD, 0x16,
    ]

    #expect(throws: MPEGTransportError.invalidTS(.invalidCRC)) {
      try TSProgramAssociationSection(bytes: bytes)
    }
  }

  @Test(
    arguments: [[UInt8]]([
      [],
      [
        0x00, 0x80, 0x11, 0x00, 0x00, 0x01, 0x00, 0x00,
        0x00, 0x01, 0x00, 0x20, 0x00, 0x02, 0x00, 0x21,
        0x94, 0x50, 0xCD,
      ],
    ])
  )
  func rejectInsufficientBufferLength(_ bytes: [UInt8]) async throws {
    #expect(throws: MPEGTransportError.bufferTooShort) {
      try TSProgramAssociationSection(bytes: bytes)
    }
  }

  @Test
  func rejectInconsistentTableID() async throws {
    let bytes: [UInt8] = [
      0x01, 0x80, 0x09,
      0x00, 0x00, 0x01, 0x00, 0x00,
      0x46, 0xC8, 0x17, 0x1B,
    ]

    #expect(throws: MPEGTransportError.invalidTS(.invalidHeader)) {
      try TSProgramAssociationSection(bytes: bytes)
    }
  }

  @Test
  func keepJustEnoughtBufferLength() async throws {
    let bytes: [UInt8] = [
      0x00, 0x80, 0x09, 0x00, 0x00, 0x01, 0x00, 0x00, 0x87, 0x64, 0x9F, 0x03,
      0x00, 0x80, 0x09,
    ]

    let sut = try TSProgramAssociationSection(bytes: bytes)

    #expect(
      sut.bytes == [
        0x00, 0x80, 0x09, 0x00, 0x00, 0x01, 0x00, 0x00, 0x87, 0x64, 0x9F, 0x03,
      ]
    )
  }

  @Test
  func rejectInvalidPID() async throws {
    let bytes: [UInt8] = [
      0x00, 0x80, 0x11,
      0x00, 0x00, 0x01, 0x00, 0x00,
      0x00, 0x01, 0x00, 0x20,
      0x00, 0x02, 0x80, 0x21,  //program number + invalid reserved + program map PID
      0xC1, 0x38, 0x6D, 0xC9,  //CRC
    ]

    #expect(throws: MPEGTransportError.invalidTS(.unexpectedPID)) {
      try TSProgramAssociationSection(bytes: bytes)
    }
  }

  @Test
  func sectionNumberShouldNotBeGreaterThanLastSectionNumber() async throws {
    let bytes: [UInt8] = [
      0x00, 0x80, 0x11,
      0x00, 0x00, 0x01,
      0x01,  //invalid section number
      0x00,  //last section number
      0x00, 0x01, 0x00, 0x20,
      0x00, 0x02, 0x00, 0x21,
      0xC3, 0x24, 0x15, 0x36,
    ]

    #expect(throws: MPEGTransportError.invalidTS(.invalidSectionNumber)) {
      try TSProgramAssociationSection(bytes: bytes)
    }
  }
}

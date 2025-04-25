import Testing

@testable import AVMediaCoders

struct TSProgramMapSectionTests {
  @Test(
    arguments: [(TSProgramMapSection, UInt16)](
      [
        (
          try! TSProgramMapSection(
            programNumber: 0,
            versionNumber: 0,
            PCRPID: .dataStream(streamID: 0),
            programInfo: [],
            programElementInfos: []
          ),
          UInt16(13)
        ),
        (
          try! TSProgramMapSection(
            programNumber: 0,
            versionNumber: 0,
            PCRPID: .dataStream(streamID: 0),
            programInfo: [0x42, 0xFF],
            programElementInfos: []
          ),
          UInt16(15)
        ),
        (
          try! TSProgramMapSection(
            programNumber: 0,
            versionNumber: 0,
            PCRPID: .dataStream(streamID: 0),
            programInfo: [0x42, 0xFF],
            programElementInfos: [
              .init(
                streamType: .videoAVC,
                elementaryPID: .dataStream(streamID: 0),
                ESInfo: [0x42, 0xFF]
              ),
              .init(
                streamType: .audioADTSAAC,
                elementaryPID: .dataStream(streamID: 1),
                ESInfo: [0x42, 0xFF, 0x42, 0xFF]
              ),
            ]
          ),
          UInt16(31)
        ),
      ]
    )
  )
  func calculateSectionLengthOnInit(_ sut: TSProgramMapSection, _ len: UInt16) async throws {
    #expect(sut.tableHeader.sectionLength == len)
  }

  @Test
  func correctHeader() async throws {
    let sut = try TSProgramMapSection(
      programNumber: 2,
      versionNumber: 4,
      PCRPID: .dataStream(streamID: 1),
      programInfo: [0x42, 0xFF],
      programElementInfos: [
        .init(
          streamType: .videoAVC,
          elementaryPID: .dataStream(streamID: 1),
          ESInfo: [0x42, 0xFF]
        ),
        .init(
          streamType: .audioADTSAAC,
          elementaryPID: .dataStream(streamID: 0),
          ESInfo: [0x42, 0xFF, 0x42, 0xFF]
        ),
      ]
    )

    #expect(
      try sut.tableHeader
        == TSTableHeader(
          tableID: .TSProgramMapSection,
          sectionLength: 31
        )
    )
    #expect(sut.PCRPID == .dataStream(streamID: 1))
    #expect(sut.versionNumber == 4)
    #expect(sut.programNumber == 2)
    #expect(sut.byteRepresentation.programInfoLength == 2)
    #expect(sut.byteRepresentation.sectionNumber == 0)
    #expect(sut.byteRepresentation.lastSectionNumber == 0)
    #expect(sut.programElementInfos.count == 2)
  }

  @Test
  func encodeEmpty() async throws {
    let sut = try TSProgramMapSection(
      programNumber: 0,
      versionNumber: 0,
      PCRPID: .dataStream(streamID: 0),
      programInfo: [],
      programElementInfos: []
    )

    #expect(
      sut.bytes == [
        0x02, 0x80, 0x0D,  // Header
        0x00, 0x00,  // Program Number
        0x01,  // Version Number + Current Next Indicator
        0x00, 0x00,  // Section Number + Last Section Number
        0x00, 0x20,  // PCR PID
        0x00, 0x00,  // Program Info Length
        0xED, 0x19, 0x74, 0x2E,  // CRC
      ]
    )
  }

  @Test
  func encodeProgramInfo() async throws {
    let sut = try TSProgramMapSection(
      programNumber: 0,
      versionNumber: 0,
      PCRPID: .dataStream(streamID: 0),
      programInfo: [0x42, 0xFF],
      programElementInfos: []
    )

    #expect(
      sut.bytes == [
        0x02, 0x80, 0x0F,  // Header
        0x00, 0x00,  // Program Number
        0x01,  // Version Number + Current Next Indicator
        0x00, 0x00,  // Section Number + Last Section Number
        0x00, 0x20,  // PCR PID
        0x00, 0x02,  // Program Info Length
        0x42, 0xFF,  // Program Info
        0xB8, 0xF5, 0x27, 0x5F,  // CRC
      ]
    )
  }

  @Test
  func encodeProgramElement() async throws {
    let sut = try TSProgramMapSection(
      programNumber: 0,
      versionNumber: 0,
      PCRPID: .dataStream(streamID: 0),
      programInfo: [],
      programElementInfos: [
        TSProgramElementInfo(
          streamType: .videoHEVC,
          elementaryPID: .dataStream(streamID: 0),
          ESInfo: [0xFF, 0x42]
        ),
        TSProgramElementInfo(
          streamType: .audioADTSAAC,
          elementaryPID: .dataStream(streamID: 1),
          ESInfo: [0x42, 0xFF, 0x42, 0xFF]
        ),
      ]
    )

    #expect(
      sut.bytes == [
        0x02, 0x80, 0x1D,  // Header
        0x00, 0x00,  // Program Number
        0x01,  // Version Number + Current Next Indicator
        0x00, 0x00,  // Section Number + Last Section Number
        0x00, 0x20,  // PCR PID
        0x00, 0x00,  // Program Info Length
        0x24, 0x00, 0x20, 0x00, 0x02, 0xFF, 0x42,  //Program Element 1
        0x0F, 0x00, 0x21, 0x00, 0x04, 0x42, 0xFF, 0x42, 0xFF,  //Program Element 2
        0xF7, 0x57, 0x1F, 0xB9,  // CRC
      ]
    )
  }

  @Test(
    arguments: [TSProgramMapSection](
      [
        try! TSProgramMapSection(
          programNumber: 1,
          versionNumber: 2,
          PCRPID: .dataStream(streamID: 3),
          programInfo: [],
          programElementInfos: []
        ),
        try! TSProgramMapSection(
          programNumber: 2,
          versionNumber: 5,
          PCRPID: .dataStream(streamID: 4),
          programInfo: [0x42, 0xFF],
          programElementInfos: []
        ),
        try! TSProgramMapSection(
          programNumber: 1,
          versionNumber: 2,
          PCRPID: .dataStream(streamID: 3),
          programInfo: [],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 0),
              ESInfo: [0xFF, 0x42]
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 1),
              ESInfo: [0x42, 0xFF, 0x42, 0xFF]
            ),
          ]
        ),
        try! TSProgramMapSection(
          programNumber: 1,
          versionNumber: 2,
          PCRPID: .dataStream(streamID: 3),
          programInfo: [0x42, 0xFF],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 0),
              ESInfo: [0xFF, 0x42]
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 1),
              ESInfo: [0x42, 0xFF, 0x42, 0xFF]
            ),
          ]
        ),
      ]
    )
  )
  func encodeDecode(_ src: TSProgramMapSection) async throws {
    let bytes = src.bytes

    let sut = try TSProgramMapSection(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func rejectInvalidCRC() async throws {
    let bytes: [UInt8] = [
      0x02, 0x80, 0x1D, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
      0x00, 0x00, 0x24, 0x00, 0x20, 0x00, 0x02, 0xFF, 0x42, 0x0F,
      0x00, 0x21, 0x00, 0x04, 0x42, 0xFF, 0x42, 0xFF,
      0xF7, 0x58, 0x1F, 0xB9,
    ]

    #expect(throws: AVMediaCodersError.invalidTS(.invalidCRC)) {
      try TSProgramMapSection(bytes: bytes)
    }
  }

  @Test(
    arguments: [[UInt8]]([
      [],
      [
        0x02, 0x80, 0x0D, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
        0x00, 0x00,  // Missing CRC
      ],
      [
        0x02, 0x80, 0x0F, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
        0x00, 0x02,  // Program info truncated
      ],
      [
        0x02, 0x80, 0x1D, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
        0x00, 0x00, 0x24, 0x00, 0x20, 0x00, 0x02, 0xFF, 0x42, 0x0F,
        0x00, 0x21, 0x00, 0x04, 0x42, 0xFF,  // Program Element truncated
      ],
    ])
  )
  func rejectInsufficientBufferLength(_ bytes: [UInt8]) async throws {
    #expect(throws: AVMediaCodersError.bufferTooShort) {
      try TSProgramMapSection(bytes: bytes)
    }
  }

  @Test
  func rejectInconsistentTableID() async throws {
    let bytes: [UInt8] = [
      0x00, 0x80, 0x0D,
      0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20, 0x00, 0x00,
      0xE2, 0xF4, 0xB2, 0x22,
    ]

    #expect(throws: AVMediaCodersError.invalidTS(.invalidHeader)) {
      try TSProgramMapSection(bytes: bytes)
    }
  }

  @Test(
    arguments: [[UInt8]](
      [
        [
          0x02, 0x80, 0x0D,
          0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x20, 0x00, 0x00,
          0xF6, 0x31, 0x79, 0x56,
        ],
        [
          0x02, 0x80, 0x0D,
          0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x20, 0x00, 0x00,
          0xA4, 0x14, 0x13, 0xA3,
        ],
      ]
    )
  )
  func rejectNonZeroSectionNumber(
    _ bytes: [UInt8]
  ) async throws {
    print(CRC32.calculate(bytes))
    #expect(throws: AVMediaCodersError.invalidTS(.invalidSectionNumber)) {
      try TSProgramMapSection(bytes: bytes)
    }
  }

  @Test
  func keepJustEnoughtBufferLength() async throws {
    let bytes: [UInt8] = [
      0x02, 0x80, 0x0F, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
      0x00, 0x02, 0x42, 0xFF, 0xB8, 0xF5, 0x27, 0x5F,
      0x02, 0x80, 0x0F,
    ]

    let sut = try TSProgramMapSection(bytes: bytes)

    #expect(
      sut.bytes == [
        0x02, 0x80, 0x0F, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x20,
        0x00, 0x02, 0x42, 0xFF, 0xB8, 0xF5, 0x27, 0x5F,
      ]
    )
  }
}

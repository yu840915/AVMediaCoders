import Testing

@testable import MPEGTransport

struct TSTableHeaderTests {
  @Test(arguments: [
    TSTableHeader.TableID.programAssociationSection,
    .conditionalAccessSection,
    .TSProgramMapSection,
    .TSDescriptionSection,
  ])
  func nonPrivateSection(_ tableID: TSTableHeader.TableID) async throws {
    let sut = try TSTableHeader(
      tableID: tableID,
      sectionLength: 42
    )

    #expect(!sut.isPrivateSection)
  }

  @Test(arguments: [
    TSTableHeader.TableID.ISO14496SceneDescriptionSection,
    .ISO14496ObjectDescriptionSection,
    .metadataSection,
    .IPMPControlInformationSection,
    .userPrivate(id: 0x01),
    .userPrivate(id: 0xBE),
  ])
  func privateSection(_ tableID: TSTableHeader.TableID) async throws {
    let sut = try TSTableHeader(
      tableID: tableID,
      sectionLength: 42
    )

    #expect(sut.isPrivateSection)
  }

  @Test(arguments: [
    TSTableHeader.TableID.programAssociationSection,
    .conditionalAccessSection,
    .TSProgramMapSection,
    .TSDescriptionSection,
    .ISO14496SceneDescriptionSection,
    .ISO14496ObjectDescriptionSection,
    .metadataSection,
    .IPMPControlInformationSection,
    .userPrivate(id: 0x01),
    .userPrivate(id: 0xBE),
  ])
  func checkLength(_ tableID: TSTableHeader.TableID) async throws {
    #expect(throws: MPEGTransportError.invalidTS(.sectionLengthOutOfBounds)) {
      try TSTableHeader(
        tableID: tableID,
        sectionLength: 0xFFFF
      )
    }
  }

  @Test
  func encode() async throws {
    let sut = try TSTableHeader(
      tableID: .programAssociationSection,
      sectionLength: 42
    )

    #expect(sut.bytes == [0x00, 0x80, 0x2A])
  }

  @Test
  func encodePrivateSection() async throws {
    let sut = try TSTableHeader(
      tableID: .userPrivate(id: 0x01),
      sectionLength: 0x0FFD
    )

    #expect(sut.bytes == [0x41, 0xCF, 0xFD])
  }

  @Test(
    arguments: [
      try! TSTableHeader(tableID: .conditionalAccessSection, sectionLength: 0),
      try! TSTableHeader(tableID: .programAssociationSection, sectionLength: 42),
      try! TSTableHeader(tableID: .TSProgramMapSection, sectionLength: 0x03FD),
      try! TSTableHeader(tableID: .TSDescriptionSection, sectionLength: 0x03FD),
      try! TSTableHeader(tableID: .ISO14496SceneDescriptionSection, sectionLength: 0x03FD),
      try! TSTableHeader(tableID: .ISO14496ObjectDescriptionSection, sectionLength: 0x03FD),
      try! TSTableHeader(tableID: .metadataSection, sectionLength: 0x42),
      try! TSTableHeader(tableID: .IPMPControlInformationSection, sectionLength: 42),
      try! TSTableHeader(tableID: .userPrivate(id: 0x01), sectionLength: 0x03FD),
      try! TSTableHeader(tableID: .userPrivate(id: 0xBE), sectionLength: 0x0FFD),
    ]
  )
  func encodeDecode(_ src: TSTableHeader) async throws {
    let bytes = src.bytes

    let sut = try TSTableHeader(bytes: bytes)

    #expect(sut == src)
  }

  @Test
  func detectBufferTooShort() async throws {
    let bytes: [UInt8] = [0x00, 0x80]

    #expect(throws: MPEGTransportError.bufferTooShort) {
      try TSTableHeader(bytes: bytes)
    }
  }

  @Test(arguments: [[0xFF, 0x80, 0x2A]])
  func rejectInvalidTableID(_ bytes: [UInt8]) async throws {
    #expect(throws: MPEGTransportError.invalidTS(.invalidHeader)) {
      try TSTableHeader(bytes: bytes)
    }
  }

  @Test(arguments: [
    [0x00, 0xC0, 0x2A],
    [0x41, 0x80, 0x2A],
  ])
  func rejectInvalidPrivateFlag(_ bytes: [UInt8]) async throws {
    #expect(throws: MPEGTransportError.invalidTS(.invalidHeader)) {
      try TSTableHeader(bytes: bytes)
    }
  }

  @Test(
    arguments: [
      [0x00, 0x83, 0xFE],
      [0x41, 0xCF, 0xFE],
    ]
  )
  func rejectInvalidLength(_ bytes: [UInt8]) async throws {
    #expect(throws: MPEGTransportError.invalidTS(.invalidHeader)) {
      try TSTableHeader(bytes: bytes)
    }
  }
}

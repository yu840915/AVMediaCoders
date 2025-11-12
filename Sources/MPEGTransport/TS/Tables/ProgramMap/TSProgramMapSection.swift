struct TSProgramMapSection: TSTableSection {
  let tableHeader: TSTableHeader
  var programNumber: UInt16 {
    byteRepresentation.programNumber
  }
  var versionNumber: UInt8 {
    byteRepresentation.versionNumber
  }
  let PCRPID: TSPID
  let byteRepresentation: ByteRepresentation
  var programInfo: [UInt8] {
    byteRepresentation.programInfo
  }
  var programElementInfos: [TSProgramElementInfo] {
    byteRepresentation.programElementInfos
  }
  var bytes: [UInt8] {
    tableHeader.bytes + byteRepresentation.bytes + crc.bigEndianBytes
  }
  let crc: UInt32

  init(
    programNumber: UInt16,
    versionNumber: UInt8,
    PCRPID: TSPID,
    programInfo: [UInt8],
    programElementInfos: [TSProgramElementInfo]
  ) throws {
    self.byteRepresentation = ByteRepresentation(
      programNumber: programNumber,
      versionNumber: versionNumber,
      PCRPID: PCRPID.value,
      programInfo: programInfo,
      programElementInfos: programElementInfos
    )
    self.tableHeader = try TSTableHeader(
      tableID: .TSProgramMapSection,
      sectionLength: UInt16(byteRepresentation.bytes.count) + 4  // CRC32
    )
    self.PCRPID = PCRPID
    crc = CRC32.calculate(
      tableHeader.bytes + byteRepresentation.bytes
    )
  }

  init(bytes: [UInt8]) throws {
    tableHeader = try TSTableHeader(bytes: bytes)
    guard tableHeader.tableID == .TSProgramMapSection else {
      throw MPEGTransportError.invalidTS(.invalidHeader)
    }
    let sectionLength = Int(tableHeader.sectionLength)
    guard bytes.dropFirst(3).count >= sectionLength else {
      throw MPEGTransportError.bufferTooShort
    }
    let contentBytes = Array(bytes.prefix(sectionLength + 3))
    crc = try UInt32(bigEndianBytes: contentBytes.suffix(4))
    if crc != CRC32.calculate(contentBytes.dropLast(4)) {
      throw MPEGTransportError.invalidTS(.invalidCRC)
    }
    byteRepresentation = try ByteRepresentation(
      bytes: Array(contentBytes.dropFirst(3).dropLast(4))
    )
    PCRPID = try TSPID(rawValue: byteRepresentation.PCRPID)
  }
}

extension TSProgramMapSection {
  struct ByteRepresentation: Equatable, Sendable {
    let programNumber: UInt16
    let versionNumber: UInt8
    let currentNextIndicator: Bool
    let sectionNumber: UInt8
    let lastSectionNumber: UInt8
    let PCRPID: UInt16
    let programInfoLength: UInt16
    let programInfo: [UInt8]
    let programElementInfos: [TSProgramElementInfo]
    let bytes: [UInt8]

    init(
      programNumber: UInt16,
      versionNumber: UInt8,
      currentNextIndicator: Bool = true,
      PCRPID: UInt16,
      programInfo: [UInt8],
      programElementInfos: [TSProgramElementInfo]
    ) {
      self.programNumber = programNumber
      self.versionNumber = versionNumber
      self.currentNextIndicator = currentNextIndicator
      self.sectionNumber = 0
      self.lastSectionNumber = 0
      self.PCRPID = PCRPID
      self.programInfoLength = UInt16(programInfo.count)
      self.programInfo = programInfo
      self.programElementInfos = programElementInfos
      let part2: UInt8 = versionNumber << 1 & 0x3E | (currentNextIndicator ? 0x01 : 0)
      bytes =
        programNumber.bigEndianBytes
        + [part2, sectionNumber, lastSectionNumber]
        + PCRPID.bigEndianBytes
        + programInfoLength.bigEndianBytes
        + programInfo
        + programElementInfos.flatMap { $0.bytes }
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 9 else {
        throw MPEGTransportError.bufferTooShort
      }
      programNumber = try UInt16(bigEndianBytes: Array(bytes[0...1]))
      let part2 = bytes[2]
      versionNumber = (part2 & 0x3E) >> 1
      currentNextIndicator = part2 & 0x01 != 0
      sectionNumber = bytes[3]
      guard sectionNumber == 0 else {
        throw MPEGTransportError.invalidTS(.invalidSectionNumber)
      }
      lastSectionNumber = bytes[4]
      guard lastSectionNumber == 0 else {
        throw MPEGTransportError.invalidTS(.invalidSectionNumber)
      }
      PCRPID = try UInt16(bigEndianBytes: Array(bytes[5...6]))
      programInfoLength = try UInt16(bigEndianBytes: Array(bytes[7...8]))
      programInfo = Array(bytes.dropFirst(9).prefix(Int(programInfoLength)))
      var programElementInfoBytes = Array(bytes.dropFirst(9 + Int(programInfoLength)))
      var programElementInfos: [TSProgramElementInfo] = []
      while !programElementInfoBytes.isEmpty {
        let programElementInfo = try TSProgramElementInfo(
          bytes: programElementInfoBytes
        )
        programElementInfoBytes.removeFirst(programElementInfo.bytes.count)
        programElementInfos.append(programElementInfo)
      }
      self.programElementInfos = programElementInfos
      self.bytes = bytes
    }
  }
}

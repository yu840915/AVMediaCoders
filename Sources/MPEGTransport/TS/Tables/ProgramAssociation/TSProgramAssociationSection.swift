import LogContext

struct TSProgramAssociationSection: TSTableSection {
  let tableHeader: TSTableHeader
  let byteRepresentation: ByteRepresentation
  var bytes: [UInt8] {
    tableHeader.bytes + byteRepresentation.bytes + crc.bigEndianBytes
  }
  var versionNumber: UInt8 {
    byteRepresentation.versionNumber
  }
  var sectionNumber: UInt8 {
    byteRepresentation.sectionNumber
  }
  var lastSectionNumber: UInt8 {
    byteRepresentation.lastSectionNumber
  }
  var isLastSection: Bool {
    sectionNumber == lastSectionNumber
  }

  let programMapPIDs: [TSPIDEntry]
  let crc: UInt32

  init(
    transportStreamId: UInt16 = 0,
    versionNumber: UInt8,
    sectionNumber: UInt8,
    lastSectionNumber: UInt8,
    programMapPIDs: [TSPIDEntry]
  ) throws {
    self.byteRepresentation = ByteRepresentation(
      transportStreamId: transportStreamId,
      versionNumber: versionNumber,
      currentNextIndicator: true,
      sectionNumber: sectionNumber,
      lastSectionNumber: lastSectionNumber,
      programMapPIDs: programMapPIDs.map { ByteRepresentation.PIDEntry($0) }
    )
    self.programMapPIDs = programMapPIDs
    self.tableHeader = try TSTableHeader(
      tableID: .programAssociationSection,
      sectionLength: UInt16(byteRepresentation.bytes.count) + 4  // CRC32
    )
    crc = CRC32.calculate(tableHeader.bytes + byteRepresentation.bytes)
  }

  init(bytes: [UInt8]) throws {
    tableHeader = try TSTableHeader(bytes: bytes)
    guard tableHeader.tableID == .programAssociationSection else {
      throw MPEGTransportError.invalidTS(.invalidHeader)
    }
    let sectionLength = Int(tableHeader.sectionLength)
    guard bytes.dropFirst(3).count >= sectionLength else {
      throw MPEGTransportError.bufferTooShort
    }
    let contentBytes = Array(bytes.prefix(Int(tableHeader.sectionLength) + 3))
    crc = try UInt32(bigEndianBytes: contentBytes.suffix(4))
    if crc != CRC32.calculate(contentBytes.dropLast(4)) {
      throw MPEGTransportError.invalidTS(.invalidCRC)
    }
    byteRepresentation = try ByteRepresentation(
      bytes: Array(contentBytes.dropFirst(3))
    )
    programMapPIDs = try byteRepresentation.programMapPIDs.map {
      try TSPIDEntry($0)
    }
  }
}

extension TSProgramAssociationSection: LogContextReadable {
  var logContext: LogContext {
    LogContext {
      $0[.id] = "PATSection"
      $0["header"] = "\(tableHeader.logContext)"
      $0["versionNumber"] = "\(versionNumber)"
      $0["sectionNumber"] = "\(sectionNumber)"
      $0["lastSectionNumber"] = "\(lastSectionNumber)"
      $0["programMapPIDs.count"] = "\(programMapPIDs.count)"
    }
  }
}

extension TSProgramAssociationSection {
  static var maxPayloadLength: Int {
    Int(TSTableHeader.TableID.programAssociationSection.maximumSectionLength)
      - ByteRepresentation.nonPayloadByteLength
  }
}

extension TSProgramAssociationSection {
  struct ByteRepresentation: Equatable, Sendable {
    static let nonPayloadByteLength = 9
    let transportStreamId: UInt16
    let versionNumber: UInt8
    let currentNextIndicator: Bool
    let sectionNumber: UInt8
    let lastSectionNumber: UInt8
    let programMapPIDs: [PIDEntry]

    var byteLength: UInt16 {
      UInt16(Self.nonPayloadByteLength) + UInt16(programMapPIDs.count * 4)
    }

    let bytes: [UInt8]

    struct PIDEntry: Equatable, Sendable {
      let programNumber: UInt16
      let programMapPID: UInt16

      init(bytes: [UInt8]) throws {
        guard bytes.count == 4 else {
          fatalError(
            "PIDEntry must be initialized with 4 bytes, got \(bytes.count)"
          )
        }
        programNumber = try UInt16(bigEndianBytes: Array(bytes.prefix(2)))
        programMapPID = try UInt16(bigEndianBytes: Array(bytes.suffix(2)))
      }

      init(_ TSPID: TSPIDEntry) {
        programNumber = TSPID.programNumber
        programMapPID = TSPID.PID.value
      }
    }

    init(
      transportStreamId: UInt16,
      versionNumber: UInt8,
      currentNextIndicator: Bool,
      sectionNumber: UInt8,
      lastSectionNumber: UInt8,
      programMapPIDs: [PIDEntry]
    ) {
      self.transportStreamId = transportStreamId
      self.versionNumber = versionNumber
      self.currentNextIndicator = currentNextIndicator
      self.sectionNumber = sectionNumber
      self.lastSectionNumber = lastSectionNumber
      self.programMapPIDs = programMapPIDs
      let part2: UInt8 = versionNumber << 1 & 0x3E | (currentNextIndicator ? 0x01 : 0)
      bytes =
        transportStreamId.bigEndianBytes
        + [part2, sectionNumber, lastSectionNumber]
        + programMapPIDs.reduce([]) { partialResult, entry in
          partialResult
            + entry.programNumber.bigEndianBytes
            + entry.programMapPID.bigEndianBytes
        }
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 9 else {
        throw MPEGTransportError.bufferTooShort
      }
      sectionNumber = bytes[3]
      lastSectionNumber = bytes[4]
      guard sectionNumber <= lastSectionNumber else {
        throw MPEGTransportError.invalidTS(.invalidSectionNumber)
      }
      transportStreamId =
        try UInt16(bigEndianBytes: Array(bytes.prefix(2)))
      versionNumber = bytes[2] >> 1 & 0x1F
      currentNextIndicator = bytes[2] & 0x01 == 0x01
      let contentBytes = bytes.dropLast(4)
      let pidBytes = Array(contentBytes.dropFirst(5))
      programMapPIDs = try stride(from: 0, through: pidBytes.count - 4, by: 4).map {
        try PIDEntry(bytes: Array(pidBytes[$0..<$0 + 4]))
      }
      self.bytes = Array(contentBytes)
    }
  }

  struct TSPIDEntry: Equatable, Sendable, LogContextReadable {
    var byteLength: UInt8 { 4 }
    let programNumber: UInt16
    let PID: TSPID
    var logContext: LogContext {
      .init {
        $0["program"] = "\(programNumber)"
        $0["PID"] = "\(PID)"
      }
    }

    init(programNumber: UInt16, PID: TSPID) {
      self.programNumber = programNumber
      self.PID = PID
    }

    init(_ rawEntry: ByteRepresentation.PIDEntry) throws {
      programNumber = rawEntry.programNumber
      PID = try TSPID(rawValue: rawEntry.programMapPID)
    }
  }
}

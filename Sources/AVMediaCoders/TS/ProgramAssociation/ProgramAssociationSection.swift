struct TSProgramAssociationSection: Equatable {
  let sectionNumber: UInt8
  let lastSectionNumber: UInt8
  let programMapPIDs: [TSPID]
}

extension TSProgramAssociationSection {
  struct ByteRepresentation: Equatable {
    let tableID: UInt8 = 0x00
    let sectionLength: UInt16
    let transportStreamId: UInt16
    let versionNumber: UInt8
    let currentNextIndicator: Bool
    let sectionNumber: UInt8
    let lastSectionNumber: UInt8
    let programMapPIDs: [PIDEntry]
    let crc: UInt32
  }

  struct PIDEntry: Equatable {
    let programNumber: UInt16
    let programMapPID: UInt16
  }
}

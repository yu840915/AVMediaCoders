struct TSProgramAssociationTable: Equatable, Sendable {
  private(set) var versionNumber: UInt8
  private(set) var programs: [UInt16: TSPID] {
    didSet {
      if oldValue != programs {
        if versionNumber < 0x1F {
          versionNumber += 1
        } else {
          versionNumber = 0
        }
      }
    }
  }

  init(
    versionNumber: UInt8 = 0,
    programs: [UInt16: TSPID] = [:]
  ) {
    self.versionNumber = versionNumber
    self.programs = programs
  }

  init(sections: [TSProgramAssociationSection]) throws {
    let version = sections[0].versionNumber
    guard sections.count == sections[0].lastSectionNumber + 1 else {
      throw AVMediaCodersError.invalidTS(.invalidSectionNumber)
    }
    self.versionNumber = version
    var programs = [UInt16: TSPID]()
    try sections.forEach {
      guard $0.versionNumber == version else {
        throw AVMediaCodersError.invalidTS(.inconsistentVersion)
      }
      $0.programMapPIDs.forEach { programs[$0.programNumber] = $0.PID }
    }
    self.programs = programs
  }

  mutating func update(
    _ updater: (inout [UInt16: TSPID]) -> Void
  ) {
    updater(&programs)
  }

  func convertToSections() -> [TSProgramAssociationSection] {
    let pids = programs.keys.sorted().map {
      TSProgramAssociationSection.TSPIDEntry(programNumber: $0, PID: programs[$0]!)
    }
    let size = TSProgramAssociationSection.maxPayloadLength / 4
    let last = pids.count / size + (pids.count % size > 0 ? 0 : -1)

    return stride(from: 0, through: last, by: 1).map {
      let start = $0 * size
      let end = min(start + size, pids.count)
      return try! TSProgramAssociationSection(
        versionNumber: versionNumber,
        sectionNumber: UInt8($0),
        lastSectionNumber: UInt8(last),
        programMapPIDs: Array(pids[start..<end])
      )
    }
  }
}

import LogContext

public struct TSProgramAssociationTable: Equatable, Sendable, LogContextReading {
  public private(set) var versionNumber: UInt8
  public private(set) var programs: [UInt16: TSPID]
  public var logContext: LogContext {
    .init {
      $0["ver"] = "\(versionNumber)"
      $0["count"] = "\(programs.count)"
      $0.setDebugDetail {
        $0["programs"] = "\(programs)"
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
      throw MPEGTransportError.invalidTS(.invalidSectionNumber)
    }
    self.versionNumber = version
    var programs = [UInt16: TSPID]()
    try sections.forEach {
      guard $0.versionNumber == version else {
        throw MPEGTransportError.invalidTS(.inconsistentVersion)
      }
      $0.programMapPIDs.forEach { programs[$0.programNumber] = $0.PID }
    }
    self.programs = programs
  }

  mutating func update(
    _ update: (inout Parameters) -> Void
  ) {
    var draft = Parameters(programs: programs)
    let oldValues = draft
    update(&draft)
    if oldValues != draft {
      programs = draft.programs
      incrementVersion()
    }
  }

  private mutating func incrementVersion() {
    if versionNumber < 0x1F {
      versionNumber += 1
    } else {
      versionNumber = 0
    }
  }

  func convertToSections() -> [TSProgramAssociationSection] {
    if programs.isEmpty {
      return [
        try! TSProgramAssociationSection(
          versionNumber: versionNumber,
          sectionNumber: 0,
          lastSectionNumber: 0,
          programMapPIDs: []
        )
      ]
    }
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

extension TSProgramAssociationTable {
  struct Parameters: Equatable, Sendable {
    var programs: [UInt16: TSPID]
  }
}

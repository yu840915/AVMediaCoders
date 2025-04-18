struct TSProgramAssociationTable: Equatable {
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

  mutating func update(
    _ updater: (inout [UInt16: TSPID]) -> Void
  ) {
    updater(&programs)
  }
}

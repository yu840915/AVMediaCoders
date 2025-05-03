struct TSProgramMapTable: Equatable, Sendable {
  let programNumber: UInt16
  private(set) var versionNumber: UInt8
  private(set) var PCRPID: TSPID
  private(set) var programInfo: [UInt8]
  private(set) var programElementInfos: [TSProgramElementInfo]

  init(
    programNumber: UInt16,
    versionNumber: UInt8 = 0,
    PCRPID: TSPID = .dataStream(streamID: 0),
    programInfo: [UInt8] = [],
    programElementInfos: [TSProgramElementInfo] = []
  ) {
    self.programNumber = programNumber
    self.versionNumber = versionNumber
    self.PCRPID = PCRPID
    self.programInfo = programInfo
    self.programElementInfos = programElementInfos
  }

  init(
    programNumber: UInt16,
    versionNumber: UInt8 = 0,
    update: Update
  ) {
    self.init(
      programNumber: programNumber,
      versionNumber: versionNumber,
      PCRPID: update.PCRPID,
      programInfo: update.programInfo,
      programElementInfos: update.programElementInfos
    )
  }

  init(section: TSProgramMapSection) {
    self.programNumber = section.programNumber
    self.versionNumber = section.versionNumber
    self.PCRPID = section.PCRPID
    self.programInfo = section.programInfo
    self.programElementInfos = section.programElementInfos
  }

  mutating func update(_ update: (inout Update) -> Void) {
    var draft = Update(
      PCRPID: PCRPID,
      programInfo: programInfo,
      programElementInfos: programElementInfos
    )
    let oldValues = draft
    update(&draft)
    if oldValues != draft {
      PCRPID = draft.PCRPID
      programInfo = draft.programInfo
      programElementInfos = draft.programElementInfos
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

  func convertToSection() throws -> TSProgramMapSection {
    try TSProgramMapSection(
      programNumber: programNumber,
      versionNumber: versionNumber,
      PCRPID: PCRPID,
      programInfo: programInfo,
      programElementInfos: programElementInfos
    )
  }
}

extension TSProgramMapTable {
  struct Update: Equatable, Sendable {
    var PCRPID: TSPID
    var programInfo: [UInt8]
    var programElementInfos: [TSProgramElementInfo]
  }
}

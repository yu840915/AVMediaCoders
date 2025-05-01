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

  init(section: TSProgramMapSection) {
    self.programNumber = section.programNumber
    self.versionNumber = section.versionNumber
    self.PCRPID = section.PCRPID
    self.programInfo = section.programInfo
    self.programElementInfos = section.programElementInfos
  }

  mutating func update(
    _ updater: (inout TSPID, inout [UInt8], inout [TSProgramElementInfo]) -> Void
  ) {
    let oldPCRPID = PCRPID
    let oldProgramInfo = programInfo
    let oldProgramElementInfos = programElementInfos
    updater(&PCRPID, &programInfo, &programElementInfos)
    if oldPCRPID != PCRPID || oldProgramInfo != programInfo
      || oldProgramElementInfos != programElementInfos
    {
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

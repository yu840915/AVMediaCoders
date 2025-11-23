public struct TSProgramMapTable: Equatable, Sendable {
  public let programNumber: UInt16
  public private(set) var versionNumber: UInt8
  public private(set) var PCRPID: TSPID
  public private(set) var programInfo: [UInt8]
  public private(set) var programElementInfos: [TSProgramElementInfo]
  var videoElements: [TSProgramElementInfo] {
    programElementInfos.filter { $0.streamType.isVideo }
  }
  var audioElements: [TSProgramElementInfo] {
    programElementInfos.filter { $0.streamType.isAudio }
  }

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
    assertValid()
  }

  init(
    programNumber: UInt16,
    versionNumber: UInt8 = 0,
    parameters: Parameters
  ) {
    self.init(
      programNumber: programNumber,
      versionNumber: versionNumber,
      PCRPID: parameters.PCRPID,
      programInfo: parameters.programInfo,
      programElementInfos: parameters.programElementInfos
    )
  }

  init(section: TSProgramMapSection) {
    self.programNumber = section.programNumber
    self.versionNumber = section.versionNumber
    self.PCRPID = section.PCRPID
    self.programInfo = section.programInfo
    self.programElementInfos = section.programElementInfos
  }

  mutating func update(_ update: (inout Parameters) -> Void) {
    var draft = Parameters(
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
      assertValid()
    }
  }

  private func assertValid() {
    guard !programElementInfos.isEmpty else {
      return
    }
    assert(
      programElementInfos.map { $0.elementaryPID }.contains(PCRPID),
      "PCRPID must be one of the elementary PIDs"
    )
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
  public struct Parameters: Equatable, Sendable {
    var PCRPID: TSPID
    var programInfo: [UInt8]
    var programElementInfos: [TSProgramElementInfo]
  }
}

private let logger = Loggers.demuxing.build()

protocol TSDemuxerOutputDelegate: AnyObject, Sendable {
  func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramAssociationTable table: TSProgramAssociationTable
  )

  func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramMapTable table: TSProgramMapTable
  )

  func demuxer(
    _ demuxer: TSDemuxer,
    didOutputESData esData: [UInt8],
    adaptationField: TSAdaptationField?,
    forPID PID: TSPID
  )
}

actor TSDemuxer {
  private let PATDepackitizer = TSDataDepacketizer(pid: .programAssociationTable)
  private var currentDepacketizer: TSDataDepacketizer?
  private(set) var programAssociationTable: TSProgramAssociationTable = .init()
  private var PATSections: [TSProgramAssociationSection] = []
  private weak var outputDelegate: TSDemuxerOutputDelegate?
  private var depacketizers: [TSPID: TSDataDepacketizer] = [:]
  private var programTables: [TSPID: TSProgramMapTable] = [:]

  init(outputDelegate: TSDemuxerOutputDelegate? = nil) {
    self.outputDelegate = outputDelegate
  }

  func feed(_ packets: [TSPacket]) {
    for packet in packets {
      feed(packet)
    }
  }

  func feed(_ packet: TSPacket) {
    if let currentPID = currentDepacketizer?.pid,
      currentPID != packet.header.PID
    {
      flush()
    }
    guard let depacketizer = loadDepacketizer(forPID: packet.header.PID) else {
      logger.debug("No depacketizer for PID \(packet.header.PID)")
      return
    }
    currentDepacketizer = depacketizer
    if let output = depacketizer.feed(packet) {
      handleOutput(output, forPID: depacketizer.pid)
    }
  }

  func flush() {
    guard let depacketizer = currentDepacketizer else {
      return
    }
    guard let output = depacketizer.flush() else {
      logger.debug("No output from depacketizer, PID \(packet.header.PID)")
      return
    }
    handleOutput(output, forPID: depacketizer.pid)
  }
}

extension TSDemuxer {
  func loadDepacketizer(forPID PID: TSPID) -> TSDataDepacketizer? {
    switch PID {
    case .programAssociationTable: PATDepackitizer
    case .dataStream: depacketizers[PID]
    default: nil
    }
  }

  func handleOutput(
    _ output: TSDataDepacketizer.Output,
    forPID PID: TSPID
  ) {
    switch PID {
    case .programAssociationTable:
      handlePATOutput(output)
    case .dataStream:
      if programTables[PID] != nil {
        handlePMTOutput(output, forPID: PID)
      } else {
        handleESDataOutput(output, forPID: PID)
      }
    default: break
    }
  }

  func handlePATOutput(_ output: TSDataDepacketizer.Output) {
    do {
      let section = try TSProgramAssociationSection(bytes: output.esData)
      PATSections.append(section)
      if !section.isLastSection {
        return
      }
      let sections = PATSections
      PATSections = []
      let table = try TSProgramAssociationTable(sections: sections)
      if programAssociationTable == table {
        return
      }
      programAssociationTable = table
      preparePMTDepacketizer()
      outputDelegate?.demuxer(self, didUpdateProgramAssociationTable: table)
    } catch {
      logger.warning("Failed to parse PAT, error: \(error)")
      return
    }
  }

  func preparePMTDepacketizer() {
    for program in programAssociationTable.programs {
      let PID = program.value
      if depacketizers[PID] == nil {
        depacketizers[PID] = TSDataDepacketizer(pid: PID)
        programTables[PID] = TSProgramMapTable(programNumber: program.key)
      }
    }
  }

  func handlePMTOutput(_ output: TSDataDepacketizer.Output, forPID PID: TSPID) {
    do {
      let section = try TSProgramMapSection(bytes: output.esData)
      let table = TSProgramMapTable(section: section)
      if programTables[PID] == table {
        return
      }
      programTables[PID] = table
      prepareProgramDepacketizer(from: table)
      outputDelegate?.demuxer(self, didUpdateProgramMapTable: table)
    } catch {
      logger.warning("Failed to parse PMT for PID: \(PID), error: \(error)")
    }
  }

  func prepareProgramDepacketizer(from table: TSProgramMapTable) {
    for stream in table.programElementInfos {
      if depacketizers[stream.elementaryPID] == nil {
        depacketizers[stream.elementaryPID] = TSDataDepacketizer(pid: stream.elementaryPID)
      }
    }
  }

  func handleESDataOutput(_ output: TSDataDepacketizer.Output, forPID PID: TSPID) {
    outputDelegate?.demuxer(
      self,
      didOutputESData: output.esData,
      adaptationField: output.adaptationField,
      forPID: PID
    )
  }
}

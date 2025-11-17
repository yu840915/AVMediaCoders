import LogContext

private let logger = Loggers.demuxing.build()

public protocol TSDemuxerOutputDelegate: AnyObject, Sendable {
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

public actor TSDemuxer: LogContextReadingActor {
  private let PATDepackitizer = TSDataDepacketizer(pid: .programAssociationTable)
  private var currentDepacketizer: TSDataDepacketizer?
  private(set) var programAssociationTable: TSProgramAssociationTable = .init()
  private var PATSections: [TSProgramAssociationSection] = []
  private weak var outputDelegate: TSDemuxerOutputDelegate?
  private var depacketizers: [TSPID: TSDataDepacketizer] = [:]
  private var programTables: [TSPID: TSProgramMapTable] = [:]
  public private(set) var logContext: LogContext

  public init(
    outputDelegate: TSDemuxerOutputDelegate? = nil,
    logContextBuilder: StructBuilder<LogContext>? = nil,
  ) {
    self.outputDelegate = outputDelegate
    logContext = LogContext {
      logContextBuilder?(&$0)
      $0.addLabel("Demuxer")
    }
  }

  public func feed(_ packets: [TSPacket]) {
    for packet in packets {
      feed(packet)
    }
  }

  public func feed(_ packet: TSPacket) {
    let context = logContext.adding {
      $0["PID"] = "\(packet.header.PID)"
      $0["action"] = "feed"
    }
    if let currentPID = currentDepacketizer?.PID,
      currentPID != packet.header.PID
    {
      logger.debug("PID changed, will flush \(context.debug)")
      flush()
    }
    guard let depacketizer = loadDepacketizer(forPID: packet.header.PID) else {
      logger.warning("Missing depacketizer \(context.warning)")
      return
    }
    currentDepacketizer = depacketizer
    if let output = depacketizer.feed(packet) {
      handleOutput(output, forPID: depacketizer.PID)
    }
  }

  public func flush() {
    var context = logContext.adding {
      $0["action"] = "flush"
    }
    guard let depacketizer = currentDepacketizer else {
      logger.trace("No depacketier to flush \(context.trace)")
      return
    }
    guard let output = depacketizer.flush() else {
      context["Depacketizer"] = depacketizer.logContext
      logger.debug("No output from depacketizer \(context.debug)")
      return
    }
    handleOutput(output, forPID: depacketizer.PID)
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
    var context = logContext.adding {
      $0["action"] = "handlePAT"
    }
    do {
      let section = try TSProgramAssociationSection(bytes: output.esData)
      context["section"] = "\(section.logContext)"
      PATSections.append(section)
      if !section.isLastSection {
        logger.debug("Appending PAT section \(context.debug)")
        return
      }
      let sections = PATSections
      PATSections = []
      let table = try TSProgramAssociationTable(sections: sections)
      if programAssociationTable == table {
        return
      }
      logger.debug("Update PAT \(context.debug)")
      programAssociationTable = table
      preparePMTDepacketizer()
      outputDelegate?.demuxer(self, didUpdateProgramAssociationTable: table)
    } catch {
      context.setError(error)
      logger.warning("Failed to parse PAT \(context.warning)")
    }
  }

  func preparePMTDepacketizer() {
    let context = logContext.adding {
      $0["action"] = "preparePMT"
    }
    for program in programAssociationTable.programs {
      let PID = program.value
      if depacketizers[PID] == nil {
        let context = context.adding {
          $0["program"] = "\(program.key)"
          $0["PID"] = "\(PID)"
        }
        let labels = logContext.labels
        depacketizers[PID] = TSDataDepacketizer(
          pid: PID,
          logContextBuilder: {
            $0.addLabels(labels)
          }
        )
        programTables[PID] = TSProgramMapTable(programNumber: program.key)
        logger.debug("Prepared depacketizer \(context.debug)")
      }
    }
    logger.info("Update PMT depacketizer \(context.info)")
  }

  func handlePMTOutput(_ output: TSDataDepacketizer.Output, forPID PID: TSPID) {
    do {
      let section = try TSProgramMapSection(bytes: output.esData)
      let table = TSProgramMapTable(section: section)
      if programTables[PID] == table {
        return
      }
      logger.debug("Update PMT over \(PID)")
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
        logger.debug(
          "Prepare depacketizer for ES of program(\(table.programNumber)) over \(stream.elementaryPID)"
        )
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

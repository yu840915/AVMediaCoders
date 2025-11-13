private let logger = Loggers.muxing.build()

public protocol TSMuxerOutputDelegate: AnyObject, Sendable {
  func muxer(_ muxer: TSMuxer, didOutputPackets packets: [TSPacket])
}

public actor TSMuxer {
  private let PATPacketizer = TSDataPacketizer(pid: .programAssociationTable)
  public private(set) var programAssociationTable: TSProgramAssociationTable
  private var programs: [UInt16: Program] = [:]
  private var esPacketizers: [UInt16: TSDataPacketizer] = [:]
  public var programTables: [UInt16: TSProgramMapTable] {
    programs.mapValues { $0.table }
  }

  private var nextAvailableStreamID: UInt16 = 0
  private weak var outputDelegate: TSMuxerOutputDelegate?

  public init(outputDelegate: TSMuxerOutputDelegate? = nil) async {
    programAssociationTable = TSProgramAssociationTable()
    self.outputDelegate = outputDelegate
    signalTable()
  }

  public func buildProgram(
    withNumberOfDataStreams numberOfDataStreams: UInt16,
    builder: ([TSPID]) -> TSProgramMapTable.Parameters
  ) throws {
    let programNumber = UInt16(programs.count + 1)
    let tableID: UInt16 = nextAvailableStreamID
    let allocatedPIDs: [TSPID] = stride(
      from: tableID + 1,
      through: tableID + numberOfDataStreams,
      by: 1
    ).map {
      .dataStream(streamID: $0)
    }
    let params = builder(allocatedPIDs)
    guard params.programElementInfos.count == numberOfDataStreams else {
      throw MPEGTransportError.muxer(.dataStreamPIDMismatch)
    }
    var usedPIDs = params.programElementInfos.map { $0.elementaryPID }
    for PID in allocatedPIDs {
      if let idx = usedPIDs.firstIndex(of: PID) {
        usedPIDs.remove(at: idx)
      } else {
        throw MPEGTransportError.muxer(.dataStreamPIDMismatch)
      }
    }
    let tablePID = TSPID.dataStream(streamID: tableID)
    for PID in allocatedPIDs {
      if case let .dataStream(streamID) = PID {
        esPacketizers[streamID] = TSDataPacketizer(pid: PID)
      }
    }
    let program = Program(
      table: TSProgramMapTable(
        programNumber: programNumber,
        parameters: params
      ),
      packetizer: TSDataPacketizer(pid: tablePID)
    )
    programs[programNumber] = program
    programAssociationTable.update {
      $0.programs[programNumber] = tablePID
    }
    nextAvailableStreamID = numberOfDataStreams + 1
    logger.info(
      "Program \(programNumber) created with PID \(tablePID)"
    )
    signalTable()
  }

  public func signalTable() {
    logger.trace("Signaling tables")
    outputDelegate?.muxer(
      self,
      didOutputPackets: packetizePAT() + packetizePMTs()
    )
  }

  public func send(
    adaptationFieldConfiguration: TSPacket.AdaptationFieldConfiguration? = nil,
    esData: [UInt8],
    forPID PID: TSPID
  ) throws {
    guard
      case let .dataStream(streamID) = PID,
      let packetizer = esPacketizers[streamID]
    else {
      throw MPEGTransportError.muxer(.dataStreamPIDMismatch)
    }
    logger.trace("Sending data for PID \(PID)")
    outputDelegate?.muxer(
      self,
      didOutputPackets: packetizer.packetize(
        adaptationFieldConfiguration: adaptationFieldConfiguration,
        esData: esData,
      )
    )
  }
}

extension TSMuxer {
  func packetizePAT() -> [TSPacket] {
    programAssociationTable.convertToSections().flatMap {
      PATPacketizer.packetize(sectionData: $0.bytes)
    }
  }

  func packetizePMTs() -> [TSPacket] {
    programs.values.flatMap { $0.packetize() }
  }
}

extension TSMuxer {
  struct Program {
    var table: TSProgramMapTable
    let packetizer: TSDataPacketizer

    func packetize() -> [TSPacket] {
      packetizer.packetize(sectionData: try! table.convertToSection().bytes)
    }
  }
}

protocol TSMuxerOutputDelegate: AnyObject, Sendable {
  func muxer(_ muxer: TSMuxer, didOutputPackets packets: [TSPacket])
}

actor TSMuxer {
  private let PATPacketizer = TSDataPacketizer(pid: .programAssociationTable)
  private(set) var programAssociationTable: TSProgramAssociationTable
  private var programs: [UInt16: Program] = [:]
  var programTables: [UInt16: TSProgramMapTable] {
    programs.mapValues { $0.table }
  }
  private var nextAvailableStreamID: UInt16 = 0
  private weak var outputDelegate: TSMuxerOutputDelegate?

  init(outputDelegate: TSMuxerOutputDelegate? = nil) {
    programAssociationTable = TSProgramAssociationTable()
    self.outputDelegate = outputDelegate
    Task {
      await signalTable()
    }
  }

  func buildProgram(
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
      throw AVMediaCodersError.invalidTS(.dataStreamPIDMismatch)
    }
    var usedPIDs = params.programElementInfos.map { $0.elementaryPID }
    for PID in allocatedPIDs {
      if let idx = usedPIDs.firstIndex(of: PID) {
        usedPIDs.remove(at: idx)
      } else {
        throw AVMediaCodersError.invalidTS(.dataStreamPIDMismatch)
      }
    }
    let tablePID = TSPID.dataStream(streamID: tableID)
    programs[programNumber] = Program(
      table: TSProgramMapTable(
        programNumber: programNumber,
        parameters: params
      ),
      packetizer: TSDataPacketizer(pid: tablePID)
    )
    programAssociationTable.update {
      $0.programs[programNumber] = tablePID
    }
    nextAvailableStreamID = numberOfDataStreams + 1
    signalTable()
  }

  func signalTable() {
    outputDelegate?.muxer(self, didOutputPackets: packetizePAT() + packetizePMTs())
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

import AsyncUtils
import Testing

@testable import AVMediaCoders

struct TSDemuxerTests {
  @Test
  func initialState() async throws {
    let sut = TSDemuxer()

    #expect(await sut.programAssociationTable.programs.isEmpty)
  }

  @Test
  func demuxTables() async throws {
    let delegate = await DemuxerDelegate(callNumber: 2)
    let sut = TSDemuxer(outputDelegate: delegate)
    let joint = Joint(demuxer: sut)
    let muxer = TSMuxer(outputDelegate: joint)

    try await muxer.buildProgram(
      withNumberOfDataStreams: 2
    ) { pids in
      .init(
        PCRPID: pids[0],
        programInfo: [],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoAVC,
            elementaryPID: pids[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: pids[1],
            ESInfo: []
          ),
        ]
      )
    }

    await sut.flush()
    try await delegate.completer.result()

    #expect(
      delegate.PAT
        == TSProgramAssociationTable(
          versionNumber: 1,
          programs: [1: .dataStream(streamID: 0)]
        )
    )
    #expect(delegate.PMTs.count == 1)
    #expect(
      delegate.PMTs[1]
        == TSProgramMapTable(
          programNumber: 1,
          parameters: .init(
            PCRPID: TSPID.dataStream(streamID: 1),
            programInfo: [],
            programElementInfos: [
              TSProgramElementInfo(
                streamType: .videoAVC,
                elementaryPID: TSPID.dataStream(streamID: 1),
                ESInfo: []
              ),
              TSProgramElementInfo(
                streamType: .audioADTSAAC,
                elementaryPID: TSPID.dataStream(streamID: 2),
                ESInfo: []
              ),
            ]
          )
        )
    )
  }

  @Test
  func demux2ProgramTables() async throws {
    let delegate = await DemuxerDelegate(callNumber: 4)
    let sut = TSDemuxer(outputDelegate: delegate)
    let joint = Joint(demuxer: sut)
    let muxer = TSMuxer(outputDelegate: joint)

    try await muxer.buildProgram(
      withNumberOfDataStreams: 2
    ) { pids in
      .init(
        PCRPID: pids[0],
        programInfo: [],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoAVC,
            elementaryPID: pids[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: pids[1],
            ESInfo: []
          ),
        ]
      )
    }
    try await muxer.buildProgram(
      withNumberOfDataStreams: 2
    ) { pids in
      .init(
        PCRPID: pids[0],
        programInfo: [],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoAVC,
            elementaryPID: pids[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: pids[1],
            ESInfo: []
          ),
        ]
      )
    }

    await sut.flush()
    try await delegate.completer.result()

    #expect(
      delegate.PAT
        == TSProgramAssociationTable(
          versionNumber: 2,
          programs: [
            1: .dataStream(streamID: 0),
            2: .dataStream(streamID: 3),
          ]
        )
    )
    #expect(delegate.PAT?.programs.count == 2)
  }

  @Test
  func demuxESStream() async throws {
    let delegate = await DemuxerDelegate(callNumber: 6)
    let sut = TSDemuxer(outputDelegate: delegate)
    let joint = Joint(demuxer: sut)
    let muxer = TSMuxer(outputDelegate: joint)

    try await muxer.buildProgram(
      withNumberOfDataStreams: 2
    ) { pids in
      .init(
        PCRPID: pids[0],
        programInfo: [],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoAVC,
            elementaryPID: pids[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: pids[1],
            ESInfo: []
          ),
        ]
      )
    }
    try await muxer.buildProgram(
      withNumberOfDataStreams: 2
    ) { pids in
      .init(
        PCRPID: pids[0],
        programInfo: [],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoAVC,
            elementaryPID: pids[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: pids[1],
            ESInfo: []
          ),
        ]
      )
    }

    try await muxer.send(esData: [0x01], forPID: .dataStream(streamID: 2))
    try await muxer.send(esData: [0x02], forPID: .dataStream(streamID: 4))
    try await muxer.send(esData: [0x03], forPID: .dataStream(streamID: 5))

    try await delegate.completer.result()
    #expect(delegate.esData[2] == [0x01])
    #expect(delegate.esData[4] == [0x02])
  }
}

private class Joint: TSMuxerOutputDelegate, @unchecked Sendable {
  let demuxer: TSDemuxer

  init(demuxer: TSDemuxer) {
    self.demuxer = demuxer
  }

  func muxer(_ muxer: AVMediaCoders.TSMuxer, didOutputPackets packets: [AVMediaCoders.TSPacket]) {
    Task {
      await demuxer.feed(packets)
    }
  }
}

private class DemuxerDelegate: TSDemuxerOutputDelegate, @unchecked Sendable {
  var PAT: TSProgramAssociationTable?
  var PMTs: [UInt16: TSProgramMapTable] = [:]
  var esData: [UInt16: [UInt8]] = [:]
  let expCallNumber: Int
  var called = 0 {
    didSet {
      if called == expCallNumber {
        markAsCompleted()
      }
    }
  }
  let completer: TimeoutThrowingCompleter<Void>
  init(callNumber: Int) async {
    self.completer = await TimeoutThrowingCompleter(waitFor: .seconds(1))
    self.expCallNumber = callNumber
  }

  func markAsCompleted() {
    Task {
      await self.completer.resume()
    }
  }

  func incrementCallCount() {
    called += 1
  }

  func demuxer(
    _ demuxer: AVMediaCoders.TSDemuxer,
    didUpdateProgramAssociationTable table: AVMediaCoders.TSProgramAssociationTable
  ) {
    PAT = table
    incrementCallCount()
  }

  func demuxer(
    _ demuxer: AVMediaCoders.TSDemuxer,
    didUpdateProgramMapTable table: AVMediaCoders.TSProgramMapTable
  ) {
    PMTs[table.programNumber] = table
    incrementCallCount()
  }

  func demuxer(
    _ demuxer: AVMediaCoders.TSDemuxer,
    didOutputESData esData: [UInt8],
    adaptationField: AVMediaCoders.TSAdaptationField?,
    forPID PID: AVMediaCoders.TSPID
  ) {
    if case let .dataStream(streamID) = PID {
      self.esData[streamID] = esData
    }
    incrementCallCount()
  }
}

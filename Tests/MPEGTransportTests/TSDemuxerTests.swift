import AsyncUtils
import Testing

@testable import MPEGTransport

struct TSDemuxerTests {
  @Test
  func initialState() async throws {
    let sut = TSDemuxer()

    #expect(await sut.programAssociationTable.programs.isEmpty)
  }

  @Test
  func demuxTables() async throws {
    let muxerDelegate = await MuxerDelegate(callNumber: 2)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
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
    let packets = (try await muxerDelegate.completer.result()).flatMap { $0 }
    let delegate = await DemuxerDelegate(callNumber: 2)
    let sut = TSDemuxer(outputDelegate: delegate)

    await sut.feed(packets)
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
    let muxerDelegate = await MuxerDelegate(callNumber: 3)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
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
    let packets = (try await muxerDelegate.completer.result()).flatMap { $0 }
    let delegate = await DemuxerDelegate(callNumber: 4)
    let sut = TSDemuxer(outputDelegate: delegate)

    await sut.feed(packets)
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
    let muxerDelegate = await MuxerDelegate(callNumber: 6)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
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
    let packets = (try await muxerDelegate.completer.result()).flatMap { $0 }
    let delegate = await DemuxerDelegate(callNumber: 6)
    let sut = TSDemuxer(outputDelegate: delegate)

    await sut.feed(packets)
    try await delegate.completer.result()
    #expect(delegate.esData[2] == [0x01])
    #expect(delegate.esData[4] == [0x02])
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
    completer = await TimeoutThrowingCompleter(waitFor: .seconds(1))
    expCallNumber = callNumber
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
    _ demuxer: TSDemuxer,
    didUpdateProgramAssociationTable table: TSProgramAssociationTable
  ) {
    PAT = table
    incrementCallCount()
  }

  func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramMapTable table: TSProgramMapTable
  ) {
    PMTs[table.programNumber] = table
    incrementCallCount()
  }

  func demuxer(
    _ demuxer: TSDemuxer,
    didOutputESData esData: [UInt8],
    adaptationField: TSAdaptationField?,
    forPID PID: TSPID
  ) {
    if case let .dataStream(streamID) = PID {
      self.esData[streamID] = esData
    }
    incrementCallCount()
  }
}

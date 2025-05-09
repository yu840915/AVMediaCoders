import AsyncUtils
import Testing

@testable import AVMediaCoders

struct TSMuxerTests {
  @Test
  func initState() async throws {
    let sut = TSMuxer()

    #expect(await sut.programAssociationTable == TSProgramAssociationTable())
    #expect(await sut.programTables.isEmpty)
  }

  @Test
  func buildFirstProgram() async throws {
    let sut = TSMuxer()

    try await sut.buildProgram(
      withNumberOfDataStreams: 2
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x42],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: streams[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: streams[1],
            ESInfo: []
          ),
        ]
      )
    }

    #expect(
      await sut.programAssociationTable
        == TSProgramAssociationTable(
          versionNumber: 1,
          programs: [1: .dataStream(streamID: 0)]
        )
    )
    #expect(
      await sut.programTables == [
        1: .init(
          programNumber: 1,
          versionNumber: 0,
          PCRPID: .dataStream(streamID: 1),
          programInfo: [0x42],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 1),
              ESInfo: []
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 2),
              ESInfo: []
            ),
          ]
        )
      ]
    )
  }

  @Test
  func buildEmptyProgram() async throws {
    let sut = TSMuxer()

    try await sut.buildProgram(
      withNumberOfDataStreams: 0
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: .nullPacket,
        programInfo: [0x42],
        programElementInfos: []
      )
    }

    #expect(
      await sut.programAssociationTable
        == TSProgramAssociationTable(
          versionNumber: 1,
          programs: [1: .dataStream(streamID: 0)]
        )
    )
    #expect(
      await sut.programTables == [
        1: .init(
          programNumber: 1,
          versionNumber: 0,
          PCRPID: .nullPacket,
          programInfo: [0x42],
          programElementInfos: []
        )
      ]
    )
  }

  @Test
  func build2Programs() async throws {
    let sut = TSMuxer()

    try await sut.buildProgram(
      withNumberOfDataStreams: 2
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x01],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: streams[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: streams[1],
            ESInfo: []
          ),
        ]
      )
    }
    try await sut.buildProgram(
      withNumberOfDataStreams: 2
    ) { streams in
      return TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x02],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: streams[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: streams[1],
            ESInfo: []
          ),
        ]
      )
    }
    #expect(
      await sut.programAssociationTable
        == TSProgramAssociationTable(
          versionNumber: 2,
          programs: [
            1: .dataStream(streamID: 0),
            2: .dataStream(streamID: 3),
          ]
        )
    )
    #expect(
      await sut.programTables == [
        1: .init(
          programNumber: 1,
          versionNumber: 0,
          PCRPID: .dataStream(streamID: 1),
          programInfo: [0x01],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 1),
              ESInfo: []
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 2),
              ESInfo: []
            ),
          ]
        ),
        2: .init(
          programNumber: 2,
          versionNumber: 0,
          PCRPID: .dataStream(streamID: 4),
          programInfo: [0x02],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 4),
              ESInfo: []
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 5),
              ESInfo: []
            ),
          ]
        ),
      ]
    )
  }

  @Test
  func numberOfStreamsMustMatch() async throws {
    let sut = TSMuxer()

    await #expect(
      throws: AVMediaCodersError.muxer(.dataStreamPIDMismatch)
    ) {
      try await sut.buildProgram(
        withNumberOfDataStreams: 2
      ) { streams in
        TSProgramMapTable.Parameters(
          PCRPID: streams[0],
          programInfo: [0x42],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: streams[0],
              ESInfo: []
            )
          ]
        )
      }
    }

    await #expect(
      throws: AVMediaCodersError.muxer(.dataStreamPIDMismatch)
    ) {
      try await sut.buildProgram(
        withNumberOfDataStreams: 0
      ) { streams in
        TSProgramMapTable.Parameters(
          PCRPID: .dataStream(streamID: 1),
          programInfo: [0x42],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: .dataStream(streamID: 1),
              ESInfo: []
            )
          ]
        )
      }
    }
  }

  @Test
  func onlyAllowsPIDsProvidedInBuilder() async throws {
    let sut = TSMuxer()

    await #expect(
      throws: AVMediaCodersError.muxer(.dataStreamPIDMismatch)
    ) {
      try await sut.buildProgram(
        withNumberOfDataStreams: 2
      ) { streams in
        TSProgramMapTable.Parameters(
          PCRPID: streams[0],
          programInfo: [0x42],
          programElementInfos: [
            TSProgramElementInfo(
              streamType: .videoHEVC,
              elementaryPID: streams[0],
              ESInfo: []
            ),
            TSProgramElementInfo(
              streamType: .audioADTSAAC,
              elementaryPID: .dataStream(streamID: 10),
              ESInfo: []
            ),
          ]
        )
      }
    }
  }

  @Test
  func signalInitialTableOnInitialization() async throws {
    let delegate = await MuxerDelegate(callNumber: 1)

    let sut = TSMuxer(outputDelegate: delegate)
    let history = try await delegate.completer.result()

    #expect(history.count == 1)
    print(sut)
  }

  @Test
  func signalTableChange() async throws {
    let delegate = await MuxerDelegate(callNumber: 2)
    let sut = TSMuxer(outputDelegate: delegate)

    try await sut.buildProgram(
      withNumberOfDataStreams: 0
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: .nullPacket,
        programInfo: [0x42],
        programElementInfos: []
      )
    }

    let history = try await delegate.completer.result()
    #expect(history.count == 2)
    #expect(
      history[0] != history[1]
    )
  }

  @Test
  func sendESData() async throws {
    let delegate = await MuxerDelegate(callNumber: 3)
    let sut = TSMuxer(outputDelegate: delegate)
    try await sut.buildProgram(
      withNumberOfDataStreams: 1
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x42],
        programElementInfos: [
          .init(
            streamType: .videoAVC,
            elementaryPID: streams[0],
            ESInfo: [0x42]
          )
        ]
      )
    }

    try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 1))
    let history = try await delegate.completer.result()

    #expect(history.count == 3)
    #expect(
      history[2] == [
        TSPacket(
          PID: .dataStream(streamID: 1),
          continuityCounter: 0x0,
          isStartOfPayload: true,
          data: [0x42]
        )
      ]
    )
  }

  @Test
  func rejectDataSentThroughUnknownPID() async throws {
    let delegate = await MuxerDelegate(callNumber: 2)
    let sut = TSMuxer(outputDelegate: delegate)
    try await sut.buildProgram(
      withNumberOfDataStreams: 1
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x42],
        programElementInfos: [
          .init(
            streamType: .videoAVC,
            elementaryPID: streams[0],
            ESInfo: [0x42]
          )
        ]
      )
    }

    await #expect(
      throws: AVMediaCodersError.muxer(.dataStreamPIDMismatch)
    ) {
      try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 2))
    }
  }

  @Test
  func rejectDataSentThroughTablePID() async throws {
    let delegate = await MuxerDelegate(callNumber: 2)
    let sut = TSMuxer(outputDelegate: delegate)
    try await sut.buildProgram(
      withNumberOfDataStreams: 1
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x42],
        programElementInfos: [
          .init(
            streamType: .videoAVC,
            elementaryPID: streams[0],
            ESInfo: [0x42]
          )
        ]
      )
    }

    await #expect(
      throws: AVMediaCodersError.muxer(.dataStreamPIDMismatch)
    ) {
      try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 0))
    }
  }

  @Test
  func sendESDataThrough2Programs() async throws {
    let delegate = await MuxerDelegate(callNumber: 7)
    let sut = TSMuxer(outputDelegate: delegate)
    try await sut.buildProgram(
      withNumberOfDataStreams: 2
    ) { streams in
      TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x01],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: streams[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: streams[1],
            ESInfo: []
          ),
        ]
      )
    }
    try await sut.buildProgram(
      withNumberOfDataStreams: 2
    ) { streams in
      return TSProgramMapTable.Parameters(
        PCRPID: streams[0],
        programInfo: [0x02],
        programElementInfos: [
          TSProgramElementInfo(
            streamType: .videoHEVC,
            elementaryPID: streams[0],
            ESInfo: []
          ),
          TSProgramElementInfo(
            streamType: .audioADTSAAC,
            elementaryPID: streams[1],
            ESInfo: []
          ),
        ]
      )
    }

    try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 1))
    try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 2))
    try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 4))
    try await sut.send(esData: [0x42], forPID: .dataStream(streamID: 5))

    let history = try await delegate.completer.result()
    #expect(history.count == 7)
  }
}

class MuxerDelegate: TSMuxerOutputDelegate, @unchecked Sendable {
  var history: [[TSPacket]] = []
  let completer: TimeoutThrowingCompleter<[[TSPacket]]>
  let callNumber: Int

  init(callNumber: Int) async {
    self.completer = await TimeoutThrowingCompleter<[[TSPacket]]>(waitFor: .seconds(1))
    self.callNumber = callNumber
  }

  func muxer(_ muxer: TSMuxer, didOutputPackets packets: [TSPacket]) {
    history.append(packets)
    if history.count == callNumber {
      Task {
        await completer.resume(history)
      }
    }
  }
}

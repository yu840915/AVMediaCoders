import Testing

@testable import MPEGTransport

struct AVProgramWriterTests {
  @Test
  func buildProgramWriter() async throws {
    let muxer = await TSMuxer()

    let sut = try await muxer.buildAVProgram(
      programInfo: [0x01, 0x02, 0x03],
      videoType: .hevc,
      audioType: .aac
    )

    #expect(sut.videoType == .hevc)
    #expect(sut.audioType == .aac)
    #expect(sut.programInfo == [0x01, 0x02, 0x03])
    #expect(sut.videoStreamPID == .dataStream(streamID: 1))
    #expect(sut.audioStreamPID == .dataStream(streamID: 2))
    #expect(
      await muxer.programAssociationTable
        == TSProgramAssociationTable(
          versionNumber: 1,
          programs: [1: .dataStream(streamID: 0)]
        )
    )
    #expect(
      await muxer.programTables == [
        1: .init(
          programNumber: 1,
          versionNumber: 0,
          PCRPID: .dataStream(streamID: 1),
          programInfo: [0x01, 0x02, 0x03],
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
  func sendVideoData() async throws {
    let delegate = await MuxerDelegate(callNumber: 3)
    let muxer = await TSMuxer(outputDelegate: delegate)
    let sut = try await muxer.buildAVProgram(
      programInfo: [0x01, 0x02, 0x03],
      videoType: .hevc,
      audioType: .aac
    )

    try await sut.sendVideoData([0x42])

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
  func sendAudioData() async throws {
    let delegate = await MuxerDelegate(callNumber: 3)
    let muxer = await TSMuxer(outputDelegate: delegate)
    let sut = try await muxer.buildAVProgram(
      programInfo: [0x01, 0x02, 0x03],
      videoType: .hevc,
      audioType: .aac
    )

    try await sut.sendAudioData([0x43])

    let history = try await delegate.completer.result()
    #expect(history.count == 3)
    #expect(
      history[2] == [
        TSPacket(
          PID: .dataStream(streamID: 2),
          continuityCounter: 0x0,
          isStartOfPayload: true,
          data: [0x43]
        )
      ]
    )
  }
}

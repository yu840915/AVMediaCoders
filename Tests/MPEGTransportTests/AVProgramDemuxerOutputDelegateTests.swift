import AsyncUtils
import Combine
import MPEGTransport
import Testing

struct AVProgramDemuxerOutputDelegateTests {
  @Test
  func notifyNewProgram() async throws {
    let muxerDelegate = await MuxerDelegate(callNumber: 2)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
    let input = try await muxer.buildAVProgram(
      programInfo: [0x42],
      videoType: .avc,
      audioType: .aac,
    )
    let muxerOutput = try await muxerDelegate.completer.result().flatMap { $0 }
    let sut = await AVProgramDemuxerOutputDelegate()

    let completer = await TimeoutThrowingCompleter<AVProgramReader>(waitFor: .seconds(1))
    var bag = Set<AnyCancellable>()
    sut.onNewProgram.sink { program in
      Task {
        await completer.resume(program)
      }
    }.store(in: &bag)

    let demuxer = TSDemuxer(outputDelegate: sut)
    await demuxer.feed(muxerOutput)
    await demuxer.flush()

    let output = try await completer.result()

    #expect(input.programInfo == output.programInfo)
    #expect(input.videoType == output.videoType)
    #expect(input.audioType == output.audioType)
  }

  @Test
  func readStreamedVideoDataThroughProgramReader() async throws {
    let muxerDelegate = await MuxerDelegate(callNumber: 3)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
    let input = try await muxer.buildAVProgram(
      programInfo: [0x01],
      videoType: .avc,
      audioType: .aac,
    )

    try await input.sendVideoPackets(
      [
        PESPacket(
          streamType:
            .video(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x01],
        )
      ]
    )
    let muxerOutput = try await muxerDelegate.completer.result()
    let sut = await AVProgramDemuxerOutputDelegate()

    let completer = await TimeoutThrowingCompleter<AVProgramReader>(waitFor: .seconds(1))
    var bag = Set<AnyCancellable>()
    sut.onNewProgram.sink { program in
      Task {
        await completer.resume(program)
      }
    }.store(in: &bag)

    let demuxer = TSDemuxer(outputDelegate: sut)
    await demuxer.feed(muxerOutput[0..<2].flatMap { $0 })
    await demuxer.flush()

    let output = try await completer.result()
    let videoDataCompleter = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    output.onVideoPacket.sink { output in
      Task {
        await videoDataCompleter.resume(output.packet)
      }
    }.store(in: &bag)

    await demuxer.feed(muxerOutput[2..<muxerOutput.count].flatMap { $0 })
    await demuxer.flush()

    #expect(
      try await videoDataCompleter.result()
        == PESPacket(
          streamType:
            .video(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x01],
        )
    )
  }

  @Test func readStreamedDataThroughProgramReader() async throws {
    let muxerDelegate = await MuxerDelegate(callNumber: 4)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
    let input = try await muxer.buildAVProgram(
      programInfo: [0x01],
      videoType: .avc,
      audioType: .aac,
    )

    try await input.sendVideoPackets(
      [
        PESPacket(
          streamType:
            .video(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x01],
        )
      ]
    )
    try await input.sendAudioPackets(
      [
        PESPacket(
          streamType:
            .audio(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x02],
        )
      ]
    )
    let muxerOutput = try await muxerDelegate.completer.result()
    let sut = await AVProgramDemuxerOutputDelegate()

    let completer = await TimeoutThrowingCompleter<AVProgramReader>(waitFor: .seconds(1))
    var bag = Set<AnyCancellable>()
    sut.onNewProgram.sink { program in
      Task {
        await completer.resume(program)
      }
    }.store(in: &bag)

    let demuxer = TSDemuxer(outputDelegate: sut)
    await demuxer.feed(muxerOutput[0..<2].flatMap { $0 })
    await demuxer.flush()

    let output = try await completer.result()
    let videoDataCompleter = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    let audioDataCompleter = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    output.onVideoPacket.sink { output in
      Task {
        await videoDataCompleter.resume(output.packet)
      }
    }.store(in: &bag)
    output.onAudioPacket.sink { output in
      Task {
        await audioDataCompleter.resume(output.packet)
      }
    }.store(in: &bag)
    await demuxer.feed(muxerOutput[2..<muxerOutput.count].flatMap { $0 })
    await demuxer.flush()

    #expect(
      try await videoDataCompleter.result()
        == PESPacket(
          streamType:
            .video(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x01],
        )
    )
    #expect(
      try await audioDataCompleter.result()
        == PESPacket(
          streamType:
            .audio(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x02],
        )
    )
  }

  @Test
  func multiplePrograms() async throws {
    let muxerDelegate = await MuxerDelegate(callNumber: 6)
    let muxer = await TSMuxer(outputDelegate: muxerDelegate)
    let input1 = try await muxer.buildAVProgram(
      programInfo: [0x01],
      videoType: .avc,
      audioType: .aac,
    )
    let input2 = try await muxer.buildAVProgram(
      programInfo: [0x02],
      videoType: .avc,
      audioType: .aac,
    )
    try await input1.sendAudioPackets(
      [
        PESPacket(
          streamType: .audio(streamID: 0, extension: .init(ptsAndDts: .none)), payload: [0x01])
      ]
    )
    try await input1.sendVideoPackets(
      [
        PESPacket(
          streamType: .video(streamID: 0, extension: .init(ptsAndDts: .none)), payload: [0x03])
      ]
    )
    try await input2.sendAudioPackets(
      [
        PESPacket(
          streamType: .audio(streamID: 0, extension: .init(ptsAndDts: .none)), payload: [0x02])
      ]
    )
    let muxerOutput = try await muxerDelegate.completer.result()

    let sut = await AVProgramDemuxerOutputDelegate()

    let prog1completer = await TimeoutThrowingCompleter<AVProgramReader>(waitFor: .seconds(1))
    let prog2completer = await TimeoutThrowingCompleter<AVProgramReader>(waitFor: .seconds(1))
    var bag = Set<AnyCancellable>()
    sut.onNewProgram.sink { program in
      Task {
        if program.programInfo == [0x01] {
          await prog1completer.resume(program)
        } else if program.programInfo == [0x02] {
          await prog2completer.resume(program)
        }
      }
    }.store(in: &bag)

    let demuxer = TSDemuxer(outputDelegate: sut)
    await demuxer.feed(muxerOutput[0..<3].flatMap { $0 })
    await demuxer.flush()

    let output1 = try await prog1completer.result()
    let output2 = try await prog2completer.result()

    let videoData1Completer = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    let audioData1Completer = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    let audioData2Completer = await TimeoutThrowingCompleter<PESPacket>(waitFor: .seconds(1))
    output1.onVideoPacket.sink { output in
      Task {
        await videoData1Completer.resume(output.packet)
      }
    }.store(in: &bag)
    output1.onAudioPacket.sink { output in
      Task {
        await audioData1Completer.resume(output.packet)
      }
    }.store(in: &bag)
    output2.onAudioPacket.sink { output in
      Task {
        await audioData2Completer.resume(output.packet)
      }
    }.store(in: &bag)
    await demuxer.feed(muxerOutput[2..<muxerOutput.count].flatMap { $0 })
    await demuxer.flush()

    #expect(
      try await videoData1Completer.result()
        == PESPacket(
          streamType:
            .video(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x03],
        )
    )
    #expect(
      try await audioData1Completer.result()
        == PESPacket(
          streamType:
            .audio(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x01],
        )
    )
    #expect(
      try await audioData2Completer.result()
        == PESPacket(
          streamType:
            .audio(streamID: 0, extension: .init(ptsAndDts: .none)),
          payload: [0x02],
        )
    )
  }
}

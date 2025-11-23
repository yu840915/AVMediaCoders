@preconcurrency import Combine
import LogContext

private let logger = Loggers.demuxing.build()

public final class AVProgramDemuxerOutputDelegate: TSDemuxerOutputDelegate {
  public var onNewProgram: AnyPublisher<AVProgramReader, Never> {
    newProgram$.eraseToAnyPublisher()
  }
  private let newProgram$: PassthroughSubject<AVProgramReader, Never>
  private let actor: DemuxerOutputDelegateActor
  private nonisolated(unsafe) var bag = Set<AnyCancellable>()

  public init(logContextBuilder: StructBuilder<LogContext>? = nil) async {
    newProgram$ = .init()
    actor = DemuxerOutputDelegateActor(
      logContext: .init {
        logContextBuilder?(&$0)
        $0.addLabel("AVDemuxer")
      }
    )
    await actor.onNewProgram
      .sink { [weak self] program in
        self?.newProgram$.send(program)
      }
      .store(in: &bag)
  }

  public func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramAssociationTable table: TSProgramAssociationTable,
  ) {
  }

  public func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramMapTable table: TSProgramMapTable,
  ) {
    Task { [weak actor] in
      await actor?.demuxer(
        demuxer,
        didUpdateProgramMapTable: table,
      )
    }
  }

  public func demuxer(
    _ demuxer: TSDemuxer,
    didOutputESData esData: [UInt8],
    adaptationField: TSAdaptationField?,
    forPID PID: TSPID,
  ) {
    Task { [weak actor] in
      await actor?.demuxer(
        demuxer,
        didOutputESData: esData,
        adaptationField: adaptationField,
        forPID: PID,
      )
    }

  }
}

actor DemuxerOutputDelegateActor {
  private var programs: [UInt16: AVProgramReader] = [:]
  private var audioReaders: [TSPID: AVProgramReader] = [:]
  private var videoReaders: [TSPID: AVProgramReader] = [:]
  public var onNewProgram: AnyPublisher<AVProgramReader, Never> {
    newProgram$.eraseToAnyPublisher()
  }
  private let newProgram$: PassthroughSubject<AVProgramReader, Never>
  private var logContext: LogContext

  init(logContext: LogContext) {
    newProgram$ = .init()
    self.logContext = logContext
  }

  public func demuxer(
    _ demuxer: TSDemuxer,
    didUpdateProgramMapTable table: TSProgramMapTable,
  ) {
    if let program = programs[table.programNumber] {
      program.updateTable(table)
      connectStreams(with: table, for: program)
    } else {
      createProgram(with: table)
    }
  }

  func createProgram(with table: TSProgramMapTable) {
    do {
      let program = try AVProgramReader(table)
      programs[table.programNumber] = program
      connectStreams(with: table, for: program)
      logContext["programs"] = "\(programs.count)"
      newProgram$.send(program)
    } catch {
      let context = logContext.adding {
        $0.setError(error)
      }
      logger.warning("Failed to create Program \(context.warning)")
    }
  }

  func connectStreams(with table: TSProgramMapTable, for program: AVProgramReader) {
    if let video = table.videoElements.first {
      videoReaders[video.elementaryPID] = program
    }
    if let audio = table.audioElements.first {
      audioReaders[audio.elementaryPID] = program
    }
  }

  public func demuxer(
    _ demuxer: TSDemuxer,
    didOutputESData esData: [UInt8],
    adaptationField: TSAdaptationField?,
    forPID PID: TSPID,
  ) {
    var context = logContext.adding {
      $0["PID"] = "\(PID)"
    }
    do {
      let packet = try PESPacket(bytes: esData)
      if let reader = videoReaders[PID] {
        reader.sendVideoPacket(adaptationField: adaptationField, packet: packet)
      } else if let reader = audioReaders[PID] {
        reader.sendAudioPacket(adaptationField: adaptationField, packet: packet)
      } else {
        logger.warning("Can't find programs to handle PES packet \(context.warning)")
      }
    } catch {
      context.setError(error)
      logger.warning("Failed to parse PES packet \(context.warning)")
    }
  }
}

public final class AVProgramReader: Sendable {
  public var onVideoPacket: AnyPublisher<PacketOutput, Never> {
    videoPacket$.eraseToAnyPublisher()
  }
  public var onAudioPacket: AnyPublisher<PacketOutput, Never> {
    audioPacket$.eraseToAnyPublisher()
  }
  public var programInfo: [UInt8] {
    table$.value.programInfo
  }
  public let videoType: VideoType
  public let audioType: AudioType

  private let videoPacket$: PassthroughSubject<PacketOutput, Never>
  private let audioPacket$: PassthroughSubject<PacketOutput, Never>
  private let table$: CurrentValueSubject<TSProgramMapTable, Never>

  init(_ table: TSProgramMapTable) throws {
    guard
      let videoStream = table.videoElements.first,
      let videoType = VideoType.from(streamType: videoStream.streamType)
    else {
      throw MPEGTransportError.demuxer(.missingVideoStream)
    }
    guard
      let audioStream = table.audioElements.first,
      let audioType = AudioType.from(streamType: audioStream.streamType)
    else {
      throw MPEGTransportError.demuxer(.missingAudioStream)
    }
    self.videoType = videoType
    self.audioType = audioType
    videoPacket$ = .init()
    audioPacket$ = .init()
    table$ = .init(table)
  }

  func updateTable(_ table: TSProgramMapTable) {
    table$.send(table)
  }

  func sendVideoPacket(
    adaptationField: TSAdaptationField?,
    packet: PESPacket
  ) {
    let output = PacketOutput(
      adaptationField: adaptationField,
      packet: packet
    )
    videoPacket$.send(output)
  }

  func sendAudioPacket(
    adaptationField: TSAdaptationField?,
    packet: PESPacket
  ) {
    let output = PacketOutput(
      adaptationField: adaptationField,
      packet: packet
    )
    audioPacket$.send(output)
  }
}

extension AVProgramReader {
  public struct PacketOutput: Sendable {
    public let adaptationField: TSAdaptationField?
    public let packet: PESPacket
  }
}

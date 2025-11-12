import Combine
import LogContext
import MPEGTransport
import VideoToolbox

private let logger = Loggers.packetizing.build()

public protocol VideoStreamPacketizing {
  var streamID: UInt8 { get }
  func packetize(_ sampleBuffer: CMSampleBuffer)
  var onOutputPES: any Publisher<PESPacket, Never> { get }
}

extension VideoStreamPacketizing {
  static func create(
    streamID: UInt8,
    configuration: VideoCompressionConfiguration
  )
    -> any VideoStreamPacketizing
  {
    VideoStreamPacketizer(streamID: streamID, configuration: configuration)
  }
}

public enum VideoCodec: LogContextValue {
  case avc
  case hevc

  public var description: String {
    switch self {
    case .avc: "AVC"
    case .hevc: "HEVC"
    }
  }
}

public struct VideoCompressionConfiguration: Sendable, LogContextReading {
  public var width: Int
  public var height: Int
  public var codec: VideoCodec
  public var bitrate: Int
  public var frameRate: Int
  public var maxKeyFrameInterval: Int
  public let logContext: LogContext

  public init(
    width: Int,
    height: Int,
    codec: VideoCodec,
    bitrate: Int,
    frameRate: Int,
    maxKeyFrameInterval: Int
  ) {
    self.width = width
    self.height = height
    self.codec = codec
    self.bitrate = bitrate
    self.frameRate = frameRate
    self.maxKeyFrameInterval = maxKeyFrameInterval
    logContext = .init {
      $0["Dimensions"] = "\(width)x\(height)"
      $0["codec"] = "\(codec)"
      $0["bitrate"] = "\(bitrate)"
      $0["FPS"] = "\(frameRate)"
      $0["maxKeyFrameInterval"] = "\(maxKeyFrameInterval)"
    }
  }
}

class VideoStreamPacketizer: VideoStreamPacketizing {

  let onOutputPES$ = PassthroughSubject<PESPacket, Never>()
  var onOutputPES: any Publisher<PESPacket, Never> {
    onOutputPES$.eraseToAnyPublisher()
  }

  let streamID: UInt8
  let compressor: VideoCompressor
  let packetizer: VideoPacketizer
  private var bag = Set<AnyCancellable>()
  let logContext: LogContext

  init(streamID: UInt8, configuration: VideoCompressionConfiguration) {
    self.streamID = streamID
    packetizer = VideoPacketizer()
    compressor = VideoCompressor(configuration: configuration)
    logContext = .init {
      $0.addLabels(["Packetizer", "VideoStream"])
      $0["streamID"] = "\(streamID)"
    }
    compressor.onCompressed.sink { [weak self] buffer in
      self?.packetizeAndNotify(buffer)
    }.store(in: &bag)
    var context = logContext
    context["config"] = configuration.logContext
    logger.info("Initialized \(context.info)")
  }

  func packetize(_ sampleBuffer: CMSampleBuffer) {
    compressor.compress(sampleBuffer: sampleBuffer)
  }

  private func packetizeAndNotify(_ sampleBuffer: CMSampleBuffer) {
    do {
      let pesPackets = try packetizer.packetize(sampleBuffer, streamID: streamID)
      pesPackets.forEach { onOutputPES$.send($0) }
    } catch {
      var context = logContext
      context.setError(error)
      logger.warning("Failed to packetize video \(context.warning)")
    }
  }
}

@preconcurrency import Combine
import DebugToolkit
import LogContext
import MPEGTransport
import VideoToolbox

private let logger = Loggers.packetizing.build()

public protocol VideoStreamPacketizing {
  var streamID: UInt8 { get }
  func packetize(_ frame: VideoFrame)
  var onOutputPES: AnyPublisher<PESPacket, Never> { get }
}

public func createVideoPacketier(
  streamID: UInt8,
  configuration: VideoCompressionConfiguration
) throws
  -> any VideoStreamPacketizing
{
  try VideoStreamPacketizer(
    streamID: streamID,
    configuration: configuration
  )
}

public struct VideoCompressionConfiguration: Sendable, LogContextReadable {
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
  var onOutputPES: AnyPublisher<PESPacket, Never> {
    onOutputPES$.eraseToAnyPublisher()
  }

  let streamID: UInt8
  let compressor: VideoCompressor
  let packetizer: VideoPacketizer
  private var bag = Set<AnyCancellable>()
  let logContext: LogContext
  private let dummy = LifecycleDummy {
    $0.addLabels(["VideoStreamPacketizer"])
  }

  init(
    streamID: UInt8,
    configuration: VideoCompressionConfiguration
  ) throws {
    self.streamID = streamID
    packetizer = VideoPacketizer()
    compressor = try VideoCompressor.create(with: configuration)
    logContext = .init {
      $0.addLabels(["Packetizer", "VideoStream"])
      $0["streamID"] = "\(streamID)"
    }
    compressor.onCompressed.sink { [weak self] frame in
      self?.packetizeAndNotify(frame)
    }.store(in: &bag)
  }

  func packetize(_ frame: VideoFrame) {
    compressor.compress(frame)
  }

  private func packetizeAndNotify(_ frame: VideoFrame) {
    do {
      let pesPackets = try packetizer.packetize(frame, streamID: streamID)
      pesPackets.forEach { onOutputPES$.send($0) }
    } catch {
      var context = logContext
      context.setError(error)
      logger.warning("Failed to packetize video \(context.warning)")
    }
  }
}

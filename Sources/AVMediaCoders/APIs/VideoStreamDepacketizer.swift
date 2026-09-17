@preconcurrency import Combine
import DebugToolkit
import LogContext
import MPEGTransport
import VideoToolbox

private let logger = Loggers.depacketizing.build()

public protocol VideoStreamDepacketizing {
  var streamID: UInt8 { get }
  func depacketize(_ pesPacket: PESPacket)
  var onOutputSampleBuffer: AnyPublisher<VideoFrame, Never> { get }
}

public func createVideoDepacketizer(
  streamID: UInt8
) -> any VideoStreamDepacketizing {
  VideoStreamDepacketizer(streamID: streamID)
}

class VideoStreamDepacketizer: VideoStreamDepacketizing {
  let outputSampleBuffer$ = PassthroughSubject<VideoFrame, Never>()
  let streamID: UInt8
  let onOutputSampleBuffer: AnyPublisher<VideoFrame, Never>
  let depacketizer: VideoDepacketizer
  private var decoder: VideoDecompressor?
  let logContext: LogContext
  private var bag = Set<AnyCancellable>()
  private let dummy = LifecycleDummy {
    $0.addLabels(["VideoStreamDepacketizer"])
  }

  init(streamID: UInt8) {
    self.streamID = streamID
    depacketizer = VideoDepacketizer()
    onOutputSampleBuffer = outputSampleBuffer$.eraseToAnyPublisher()
    logContext = .init {
      $0.addLabels(["Depacketizer", "VideoStream"])
      $0["streamID"] = "\(streamID)"
    }
  }

  func depacketize(_ pesPacket: PESPacket) {
    do {
      let frames = try depacketizer.depacketize(pesPacket)
      for frame in frames {
        decode(frame)
      }
    } catch {
      let context = logContext.adding {
        $0.setError(error)
      }
      logger.warning("Failed to depacketize video \(context.warning)")
    }
  }

  func decode(
    _ frame: VideoFrame
  ) {
    let context = logContext
    if let decoder {
      logger.trace("Will decode frame \(context.trace)")
      decoder.decompress(frame)
    } else if let format = frame.buffer.formatDescription {
      let decoder = try! VideoDecompressor.create(formatDescription: format)
      logger.trace("Set up decoder \(context.trace)")
      setUp(for: decoder)
      decoder.decompress(frame)
    }
  }

  func setUp(for decoder: VideoDecompressor) {
    self.decoder = decoder
    var bag = Set<AnyCancellable>()
    decoder.onDecompressed.sink { [weak self] output in
      self?.send(output)
    }.store(in: &bag)
    decoder.onError.sink { [weak self] error in
      self?.handle(error)
    }.store(in: &bag)
    self.bag = bag
  }

  func send(_ frame: VideoFrame) {
    let context = logContext
    logger.trace("Decoded frame into sample buffer \(context.trace)")
    outputSampleBuffer$.send(frame)
  }

  func handle(_ error: any Error) {
    let context = logContext.adding {
      $0.setError(error)
    }
    logger.warning("Decoder error \(context.warning)")
  }
}

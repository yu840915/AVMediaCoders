@preconcurrency import Combine
import LogContext
import MPEGTransport
import VideoToolbox

private let logger = Loggers.depacketizing.build()

public protocol VideoStreamDepacketizing {
  var streamID: UInt8 { get }
  func depacketize(_ pesPacket: PESPacket)
  var onOutputSampleBuffer: AnyPublisher<CMSampleBuffer, Never> { get }
}

public func createVideoDepacketizer(
  streamID: UInt8
) -> any VideoStreamDepacketizing {
  VideoStreamDepacketizer(streamID: streamID)
}

class VideoStreamDepacketizer: VideoStreamDepacketizing {
  let outputSampleBuffer$ = PassthroughSubject<CMSampleBuffer, Never>()
  let streamID: UInt8
  let onOutputSampleBuffer: AnyPublisher<CMSampleBuffer, Never>
  let depacketizer: VideoDepacketizer
  private var decoder: VideoDecompressor?
  let logContext: LogContext
  private var bag = Set<AnyCancellable>()

  init(streamID: UInt8) {
    self.streamID = streamID
    depacketizer = VideoDepacketizer()
    onOutputSampleBuffer = outputSampleBuffer$.eraseToAnyPublisher()
    logContext = .init {
      $0.addLabels(["Depacketizer", "VideoStream"])
      $0["streamID"] = "\(streamID)"
    }
    let context = logContext
    logger.info("Initialized \(context.info)")
  }

  func depacketize(_ pesPacket: PESPacket) {
    do {
      let buffers = try depacketizer.depacketize(pesPacket)
      for buffer in buffers {
        // outputSampleBuffer$.send(buffer)
        decode(buffer)
      }
    } catch {
      let context = logContext.adding {
        $0.setError(error)
      }
      logger.warning("Failed to depacketize video \(context.warning)")
    }
  }

  func decode(
    _ buffer: CMSampleBuffer
  ) {
    let context = logContext
    if let decoder {
      logger.trace("Will decode frame \(context.trace)")
      decoder.decompress(buffer)
    } else if let format = buffer.formatDescription {
      let decoder = try! VideoDecompressor.create(formatDescription: format)
      logger.trace("Set up decoder \(context.trace)")
      setUp(for: decoder)
      decoder.decompress(buffer)
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

  func send(_ buffer: CMSampleBuffer) {
    let context = logContext
    logger.trace("Decoded frame into sample buffer \(context.trace)")
    outputSampleBuffer$.send(buffer)
  }

  func handle(_ error: any Error) {
    let context = logContext.adding {
      $0.setError(error)
    }
    logger.warning("Decoder error \(context.warning)")
  }
}

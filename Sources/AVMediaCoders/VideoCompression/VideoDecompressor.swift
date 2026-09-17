@preconcurrency import Combine
import LogContext
import RemoteCameraCore
import VideoToolbox

private let logger = Loggers.decompressing.build()

public final class VideoDecompressor: LogContextReadable {
  private(set) var compressedBufferFormatDescription: CMVideoFormatDescription
  private(set) var decompressionSession: VTDecompressionSession!
  private var imageBufferFormatDescription: CMVideoFormatDescription?
  private let decompressedBuffer$ = PassthroughSubject<VideoFrame, Never>()
  private let error$: PassthroughSubject<any Error, Never> = PassthroughSubject<Error, Never>()
  public let onDecompressed: AnyPublisher<VideoFrame, Never>
  public let onError: AnyPublisher<Error, Never>
  public let logContext: LogContext
  private let annotations: VideoFrameAnnotationActor
  private let events: AsyncStream<AnnotationEvent>.Continuation
  private var pump: Task<Void, Never>?

  init(formatDescription: CMVideoFormatDescription) {
    compressedBufferFormatDescription = formatDescription
    onDecompressed = decompressedBuffer$.eraseToAnyPublisher()
    onError = error$.eraseToAnyPublisher()
    logContext = LogContext {
      $0.addLabel(.videoDecompressor)
    }
    annotations = VideoFrameAnnotationActor()
    let (stream, continuation) = AsyncStream.makeStream(of: AnnotationEvent.self)
    events = continuation
    pump = startPump(for: stream)
  }

  deinit {
    events.finish()
    pump?.cancel()
    if let decompressionSession {
      VTDecompressionSessionInvalidate(decompressionSession)
    }
  }

  private func startPump(
    for stream: AsyncStream<AnnotationEvent>
  ) -> Task<Void, Never> {
    let annotations = self.annotations
    nonisolated(unsafe) let subject = decompressedBuffer$
    return Task {
      for await event in stream {
        switch event {
        case .annotate(let annotation):
          await annotations.push(annotation)
        case .output(let output):
          let annotation = await annotations.popUntil(output.timestamp)
          subject.send(
            VideoFrame(
              buffer: output.buffer,
              imageOrientation: annotation?.imageOrientation,
              inputDeviceDirection: annotation?.inputDeviceDirection
            )
          )
        }
      }
    }
  }

  public func decompress(_ frame: VideoFrame) {
    var outFlags: VTDecodeInfoFlags = []
    let buffer = frame.buffer
    events.yield(
      .annotate(
        VideoFrameAnnotation(
          timestamp: buffer.presentationTimeStamp,
          imageOrientation: frame.imageOrientation,
          inputDeviceDirection: frame.inputDeviceDirection
        )
      )
    )
    if let newFormat = buffer.formatDescription,
      !VTDecompressionSessionCanAcceptFormatDescription(
        decompressionSession,
        formatDescription: newFormat
      )
    {
      let context = logContext.adding {
        $0.addLabel(.videoCodec)
        $0["old"] = compressedBufferFormatDescription.logContext
        $0["new"] = newFormat.logContext
      }
      logger.notice(
        "Session rejected the frame's format description, recreating \(context.notice)")
      do {
        let newSession = try VideoDecompressor.createDecompressionSession(
          formatDescription: newFormat,
          decompressor: self
        )
        let oldSession = decompressionSession
        decompressionSession = newSession
        compressedBufferFormatDescription = newFormat
        if let oldSession {
          VTDecompressionSessionInvalidate(oldSession)
        }
      } catch {
        let context = context.adding {
          $0.setError(error)
        }
        logger.error("Cannot recreate decompression session \(context.error)")
        error$.send(error)
      }
    }
    let context = logContext.adding {
      $0.addLabel(.videoCodec)
      $0["buffer"] = buffer.logContext
    }
    let status = VTDecompressionSessionDecodeFrame(
      decompressionSession,
      sampleBuffer: buffer,
      flags: [],
      frameRefcon: nil,
      infoFlagsOut: &outFlags
    )
    if status != noErr {
      let failure = context.adding {
        $0["status"] = "\(status)"
        $0["stage"] = "VTDecompressionSessionDecodeFrame"
        $0["sessionFormat"] = compressedBufferFormatDescription.logContext
      }
      logger.error("Cannot submit frame to decoder \(failure.error)")
      error$.send(AVMediaCodersError.framework(status))
    }
  }

  private func processDecompressorResult(
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    buffer: CVImageBuffer?,
    timestamp: CMTime,
    duration: CMTime
  ) {
    guard status == noErr else {
      let context = logContext.adding {
        $0["status"] = "\(status)"
        $0["stage"] = "decompressionOutputCallback"
        $0["pts"] = "\(timestamp.seconds)"
      }
      logger.error("Decoder returned a failure for a frame \(context.error)")
      error$.send(AVMediaCodersError.framework(status))
      return
    }
    guard !infoFlags.contains(.frameDropped) else {
      error$.send(AVMediaCodersError.frameDropped)
      return
    }
    guard let buffer else {
      error$.send(AVMediaCodersError.missingBuffer)
      return
    }
    do {
      let sampleBuffer = try createSampleBuffer(
        from: buffer,
        timestamp: timestamp,
        duration: duration
      )
      events.yield(
        .output(DecodedOutput(buffer: sampleBuffer, timestamp: timestamp))
      )
    } catch {
      let context = logContext.adding {
        $0.setError(error)
        $0["stage"] = "wrapping the decoded pixel buffer"
      }
      logger.error("Cannot wrap decoded frame in a sample buffer \(context.error)")
      error$.send(error)
    }
  }

  private func createSampleBuffer(
    from pixelBuffer: CVImageBuffer,
    timestamp: CMTime,
    duration: CMTime
  ) throws -> CMSampleBuffer {
    var timingInfo = CMSampleTimingInfo(
      duration: duration,
      presentationTimeStamp: timestamp,
      decodeTimeStamp: .invalid
    )
    let decodedFormat = try createImageFormatIfMismatch(for: pixelBuffer)
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: decodedFormat,
      sampleTiming: &timingInfo,
      sampleBufferOut: &sampleBuffer
    )
    guard status == noErr, let sampleBuffer else {
      throw AVMediaCodersError.framework(status)
    }
    return sampleBuffer
  }

  private func createImageFormatIfMismatch(
    for pixelBuffer: CVImageBuffer
  ) throws -> CMVideoFormatDescription {
    if let imageBufferFormatDescription,
      CMVideoFormatDescriptionMatchesImageBuffer(
        imageBufferFormatDescription,
        imageBuffer: pixelBuffer
      )
    {
      return imageBufferFormatDescription
    }
    var format: CMVideoFormatDescription?
    try ensureSuccess(
      osStatus: CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer,
        formatDescriptionOut: &format
      )
    )
    guard let format else {
      throw AVMediaCodersError.missingBuffer
    }
    imageBufferFormatDescription = format
    return format
  }
}

extension VideoDecompressor {
  public static func create(
    formatDescription: CMVideoFormatDescription
  ) throws -> VideoDecompressor {
    let decompressor = VideoDecompressor(
      formatDescription: formatDescription
    )
    let session = try createDecompressionSession(
      formatDescription: formatDescription,
      decompressor: decompressor
    )
    decompressor.decompressionSession = session
    return decompressor
  }

  static func createDecompressionSession(
    formatDescription: CMVideoFormatDescription,
    decompressor: VideoDecompressor
  ) throws -> VTDecompressionSession {
    var session: VTDecompressionSession?
    var formatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    let attr =
      [
        kCVPixelBufferPixelFormatTypeKey as NSString: CFNumberCreate(
          kCFAllocatorDefault, .sInt32Type, &formatType)
      ] as CFDictionary

    var record = VTDecompressionOutputCallbackRecord()
    record.decompressionOutputCallback = VideoDecompressor.outputCallback
    record.decompressionOutputRefCon = Unmanaged.passUnretained(decompressor).toOpaque()
    try ensureSuccess(
      osStatus: VTDecompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        formatDescription: formatDescription,
        decoderSpecification: attr,
        imageBufferAttributes: nil,
        outputCallback: &record,
        decompressionSessionOut: &session
      )
    )
    guard
      let session,
      VTDecompressionSessionCanAcceptFormatDescription(
        session,
        formatDescription: formatDescription
      )
    else {
      throw AVMediaCodersError.cannotCreateDecompressor
    }
    return session
  }

  static let outputCallback: VTDecompressionOutputCallback = {
    (
      outputCallbackRefCon: UnsafeMutableRawPointer?,
      sourceFrameRefCon: UnsafeMutableRawPointer?,
      status: OSStatus,
      infoFlags: VTDecodeInfoFlags,
      buffer: CVImageBuffer?,
      timestamp: CMTime,
      duration: CMTime
    ) in
    var context = LogContext {
      $0.addLabel(.videoDecompressor)
    }
    guard let refcon: UnsafeMutableRawPointer = outputCallbackRefCon else {
      context["reason"] = "Missing refcon"
      logger.warning("Decompression failed \(context.warning)")
      return
    }
    let ptr = Unmanaged<VideoDecompressor>.fromOpaque(refcon)
    guard let decompressor = ptr.takeUnretainedValue() as VideoDecompressor? else {
      context["reason"] = "Missing decompressor"
      logger.warning("Decompression failed \(context.warning)")
      return
    }
    guard let pixelBuffer: CVPixelBuffer = buffer else {
      context["reason"] = "Missing pixel buffer"
      logger.warning("Decompression failed \(context.warning)")
      return
    }
    sourceFrameRefCon?.assumingMemoryBound(to: CVPixelBuffer.self).pointee = pixelBuffer
    decompressor.processDecompressorResult(
      sourceFrameRefCon: sourceFrameRefCon,
      status: status,
      infoFlags: infoFlags,
      buffer: pixelBuffer,
      timestamp: timestamp,
      duration: duration
    )
  }
}

actor VideoFrameAnnotationActor {
  private(set) var annotations: [VideoFrameAnnotation] = []
  private var latest: VideoFrameAnnotation?
  private let capacity = 120

  func push(_ annotation: VideoFrameAnnotation) {
    if let last = annotations.last,
      last.timestamp >= annotation.timestamp
    {
      return
    }
    annotations.append(annotation)
    if annotations.count > capacity {
      annotations.removeFirst(annotations.count - capacity)
    }
  }

  func popUntil(_ timestamp: CMTime) -> VideoFrameAnnotation? {
    var annotation: VideoFrameAnnotation?
    while let first = annotations.first, first.timestamp <= timestamp {
      annotation = first
      annotations.removeFirst()
    }
    if let annotation {
      latest = annotation
    }
    return annotation ?? latest
  }
}

private struct DecodedOutput: @unchecked Sendable {
  let buffer: CMSampleBuffer
  let timestamp: CMTime
}

private enum AnnotationEvent: Sendable {
  case annotate(VideoFrameAnnotation)
  case output(DecodedOutput)
}

struct VideoFrameAnnotation: Sendable {
  let timestamp: CMTime
  let imageOrientation: ImageOrientation?
  let inputDeviceDirection: DeviceDirection?
}

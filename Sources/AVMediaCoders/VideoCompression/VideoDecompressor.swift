import Combine
import VideoToolbox

private let logger = Loggers.decompressing.build()

final class VideoDecompressor {
  let formatDescription: CMVideoFormatDescription
  private(set) var decompressionSession: VTDecompressionSession!
  private let decompressedBuffer$ = PassthroughSubject<CMSampleBuffer, Never>()
  private let error$ = PassthroughSubject<Error, Never>()
  var onDecompressed: AnyPublisher<CMSampleBuffer, Never> {
    decompressedBuffer$.eraseToAnyPublisher()
  }
  var onError: AnyPublisher<Error, Never> { error$.eraseToAnyPublisher() }

  init(formatDescription: CMVideoFormatDescription) {
    self.formatDescription = formatDescription
  }

  public func decompress(_ buffer: CMSampleBuffer) {
    var outFlags: VTDecodeInfoFlags = []
    let status = VTDecompressionSessionDecodeFrame(
      decompressionSession,
      sampleBuffer: buffer,
      flags: [],
      frameRefcon: nil,
      infoFlagsOut: &outFlags
    )
    if status != noErr {
      error$.send(AVMediaCodersError.framework(status))
    }
  }

  private func processDecompressorResult(
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTDecodeInfoFlags,
    buffer: CVImageBuffer?,
    timestamp: CMTime,
    duration: CMTime,
  ) {
    guard status == noErr else {
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
        duration: duration,
      )
      decompressedBuffer$.send(sampleBuffer)
    } catch {
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
    var sampleBuffer: CMSampleBuffer?
    let status = CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault,
      imageBuffer: pixelBuffer,
      formatDescription: formatDescription,
      sampleTiming: &timingInfo,
      sampleBufferOut: &sampleBuffer
    )
    guard status == noErr, let sampleBuffer else {
      throw AVMediaCodersError.framework(status)
    }
    return sampleBuffer
  }
}

extension VideoDecompressor {
  public static func create(formatDescription: CMVideoFormatDescription) throws -> VideoDecompressor
  {
    var session: VTDecompressionSession?
    let decompressor = VideoDecompressor(formatDescription: formatDescription)
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
        decoderSpecification: nil,
        imageBufferAttributes: attr,
        outputCallback: &record,
        decompressionSessionOut: &session
      )
    )
    guard let session else {
      throw AVMediaCodersError.cannotCreateDecompressor
    }
    decompressor.decompressionSession = session
    return decompressor
  }

  static let outputCallback: VTDecompressionOutputCallback = {
    (
      outputCallbackRefCon: UnsafeMutableRawPointer?,
      sourceFrameRefCon: UnsafeMutableRawPointer?,
      status: OSStatus,
      infoFlags: VTDecodeInfoFlags,
      buffer: CVImageBuffer?,
      timestamp: CMTime,
      duration: CMTime,
    ) in
    guard let refcon: UnsafeMutableRawPointer = outputCallbackRefCon else {
      logger.warning("Missing refcon")
      return
    }
    let ptr = Unmanaged<VideoDecompressor>.fromOpaque(refcon)
    guard let decompressor = ptr.takeUnretainedValue() as VideoDecompressor? else {
      logger.warning("Missing compressor")
      return
    }
    guard let pixelBuffer: CVPixelBuffer = buffer else {
      logger.warning("Cannot get pixel buffer")
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

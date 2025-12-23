@preconcurrency import Combine
import LogContext
import VideoToolbox

private let logger = Loggers.compressing.build()

extension VideoCompressionConfiguration {
  var properties: [CFString: CFTypeRef] {
    [
      kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
      kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse,
      kVTCompressionPropertyKey_ExpectedFrameRate: frameRate as CFNumber,
      kVTCompressionPropertyKey_AverageBitRate: bitrate as CFNumber,
      kVTCompressionPropertyKey_MaxKeyFrameInterval: maxKeyFrameInterval as CFNumber,
    ]
  }

  var logContextExt: LogContext {
    logContext.adding {
      $0.setDebugDetail { ctx in
        properties.forEach { key, value in
          ctx["\(key)"] = "\(value)"
        }
        codec.properties.forEach { key, value in
          ctx["\(key)"] = "\(value)"
        }
      }
    }
  }
}

public final class VideoCompressor: LogContextReading {
  let configuration: VideoCompressionConfiguration
  fileprivate(set) var compressionSession: VTCompressionSession!
  fileprivate let compressedBuffer$: PassthroughSubject<CMSampleBuffer, Never>
  fileprivate let error$: PassthroughSubject<any Error, Never>
  public let onCompressed: AnyPublisher<CMSampleBuffer, Never>
  public let onError: AnyPublisher<any Error, Never>
  public let logContext: LogContext

  private init(configuration: VideoCompressionConfiguration) {
    self.configuration = configuration
    compressedBuffer$ = PassthroughSubject<CMSampleBuffer, Never>()
    error$ = PassthroughSubject<any Error, Never>()
    onCompressed = compressedBuffer$.eraseToAnyPublisher()
    onError = error$.eraseToAnyPublisher()
    logContext = LogContext {
      $0.addLabel(.videoCompressor)
    }
    let context = configuration.logContext.adding {
      $0.addLabel(.videoCompressor)
    }
    logger.info("Created \(context.info)")
  }

  public func compress(sampleBuffer: CMSampleBuffer) {
    guard let imageBuf = sampleBuffer.imageBuffer else {
      let context = logContext
      logger.warning("Cannot get img buf \(context.warning)")
      return
    }
    var flags: VTEncodeInfoFlags = []
    let status = VTCompressionSessionEncodeFrame(
      compressionSession,
      imageBuffer: imageBuf,
      presentationTimeStamp: sampleBuffer.presentationTimeStamp,
      duration: sampleBuffer.duration,
      frameProperties: nil,
      sourceFrameRefcon: nil,
      infoFlagsOut: &flags,
    )
    if status != noErr {
      error$.send(AVMediaCodersError.framework(status))
    }
  }

  private func processCompressorResult(
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?
  ) {
    guard status == noErr else {
      error$.send(AVMediaCodersError.framework(status))
      return
    }
    guard !infoFlags.contains(.frameDropped) else {
      error$.send(AVMediaCodersError.frameDropped)
      return
    }
    guard let sampleBuffer else {
      error$.send(AVMediaCodersError.missingBuffer)
      return
    }
    let context = logContext.adding {
      $0.addLabel(.videoCodec)
      $0["buffer"] = sampleBuffer.logContext
    }
    logger.trace("Compressed frame \(context.trace)")
    compressedBuffer$.send(sampleBuffer)
  }
}

extension VideoCodec {
  var cmVideoCodecType: CMVideoCodecType {
    switch self {
    case .avc: kCMVideoCodecType_H264
    case .hevc: kCMVideoCodecType_HEVC
    }
  }

  var properties: [CFString: CFTypeRef] {
    switch self {
    case .avc:
      [
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Main_AutoLevel
      ]
    case .hevc:
      [
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_HEVC_Main_AutoLevel
      ]
    }
  }
}

extension VideoCompressor {
  public static func create(
    with configuration: VideoCompressionConfiguration
  ) throws -> VideoCompressor {
    var session: VTCompressionSession?
    let compressor = VideoCompressor(configuration: configuration)
    var formatType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
    let attr =
      [
        kCVPixelBufferPixelFormatTypeKey as NSString: CFNumberCreate(
          kCFAllocatorDefault, .sInt32Type, &formatType)
      ] as CFDictionary

    try ensureSuccess(
      osStatus:
        VTCompressionSessionCreate(
          allocator: kCFAllocatorDefault,
          width: Int32(configuration.width),
          height: Int32(configuration.height),
          codecType: configuration.codec == .avc ? kCMVideoCodecType_H264 : kCMVideoCodecType_HEVC,
          encoderSpecification: nil,
          imageBufferAttributes: attr,
          compressedDataAllocator: nil,
          outputCallback: compressionOutbutCallback,
          refcon: Unmanaged.passUnretained(compressor).toOpaque(),
          compressionSessionOut: &session,
        )
    )
    guard let session else {
      throw AVMediaCodersError.cannotCreateCompressor
    }
    try ensureSuccess(
      osStatus:
        VTSessionSetProperty(
          session,
          key: kVTCompressionPropertyKey_RealTime,
          value: kCFBooleanTrue,
        )
    )
    VTCompressionSessionPrepareToEncodeFrames(session)

    try configuration.properties.forEach { key, value in
      try ensureSuccess(
        osStatus:
          VTSessionSetProperty(session, key: key, value: value)
      )
    }
    try configuration.codec.properties.forEach { key, value in
      try ensureSuccess(
        osStatus:
          VTSessionSetProperty(session, key: key, value: value)
      )
    }
    let context = configuration.logContextExt.adding {
      $0.addLabel(.videoCompressor)
    }
    logger.debug("Configured session \(context.debug)")
    compressor.compressionSession = session
    return compressor
  }

  static let compressionOutbutCallback: VTCompressionOutputCallback = {
    (
      outputCallbackRefCon: UnsafeMutableRawPointer?,
      sourceFrameRefCon: UnsafeMutableRawPointer?,
      status: OSStatus,
      infoFlags: VTEncodeInfoFlags,
      sampleBuffer: CMSampleBuffer?
    ) in
    let context = LogContext {
      $0.addLabel(.videoCompressor)
    }
    guard let refcon: UnsafeMutableRawPointer = outputCallbackRefCon else {
      logger.warning("Missing refcon \(context.warning)")
      return
    }
    let ptr = Unmanaged<VideoCompressor>.fromOpaque(refcon)
    guard let compressor = ptr.takeUnretainedValue() as VideoCompressor? else {
      logger.warning("Missing compressor \(context.warning)")
      return
    }
    compressor.processCompressorResult(
      sourceFrameRefCon: sourceFrameRefCon,
      status: status,
      infoFlags: infoFlags,
      sampleBuffer: sampleBuffer
    )
  }
}

extension CFNumber {
  class func with<T>(value: T, type: CFNumberType) -> CFNumber {
    var val: T = value
    return withUnsafePointer(to: &val) { ptr in
      CFNumberCreate(kCFAllocatorDefault, type, ptr)
    }
  }
}

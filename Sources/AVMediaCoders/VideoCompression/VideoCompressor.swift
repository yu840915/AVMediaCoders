import Combine
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
}

public final class VideoCompressor {
  let configuration: VideoCompressionConfiguration
  fileprivate(set) var compressionSession: VTCompressionSession!
  fileprivate let compressedBuffer$ = PassthroughSubject<CMSampleBuffer, Never>()
  fileprivate let error$ = PassthroughSubject<Error, Never>()
  public var onCompressed: any Publisher<CMSampleBuffer, Never> { compressedBuffer$ }
  public var onError: any Publisher<Error, Never> { error$ }

  init(configuration: VideoCompressionConfiguration) {
    self.configuration = configuration
  }

  public func compress(sampleBuffer: CMSampleBuffer) {
    guard let imageBuf = sampleBuffer.imageBuffer else {
      logger.warning("Cannot get img buf")
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
      infoFlagsOut: &flags
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
    logger.trace("Compressed frame")
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
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_H264_Main_AutoLevel,
      ]
    case .hevc:
      [
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_HEVC_Main_AutoLevel,
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

    try ensureSuccess(
      osStatus:
        VTCompressionSessionCreate(
          allocator: kCFAllocatorDefault,
          width: Int32(configuration.width),
          height: Int32(configuration.height),
          codecType: configuration.codec == .avc ? kCMVideoCodecType_H264 : kCMVideoCodecType_HEVC,
          encoderSpecification: nil,
          imageBufferAttributes: nil,
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
      logger.trace("Setting \(key) to \(value.description)")
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
    guard let refcon: UnsafeMutableRawPointer = outputCallbackRefCon else {
      logger.warning("Missing refcon")
      return
    }
    let ptr = Unmanaged<VideoCompressor>.fromOpaque(refcon)
    guard let compressor = ptr.takeUnretainedValue() as VideoCompressor? else {
      logger.warning("Missing compressor")
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

@preconcurrency import Combine
import DebugToolkit
import LogContext
import RemoteCameraCore
@preconcurrency import VideoToolbox

private let logger = Loggers.compressing.build()

extension VideoCompressionConfiguration {
  var properties: [CFString: CFTypeRef] {
    let limits: [NSNumber] = [NSNumber(value: bitrate), NSNumber(value: 1)]
    return [
      kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
      kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse,
      kVTCompressionPropertyKey_ExpectedFrameRate: frameRate as CFNumber,
      kVTCompressionPropertyKey_AverageBitRate: bitrate as CFNumber,
      kVTCompressionPropertyKey_MaxKeyFrameInterval: maxKeyFrameInterval as CFNumber,
      kVTCompressionPropertyKey_DataRateLimits: limits as CFArray
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

public final class VideoCompressor: LogContextReadable, Sendable {
  let configuration: VideoCompressionConfiguration
  fileprivate nonisolated(unsafe) let compressionSession: VTCompressionSession
  fileprivate let compressedBuffer$: PassthroughSubject<VideoFrame, Never>
  fileprivate let error$: PassthroughSubject<any Error, Never>
  public let onCompressed: AnyPublisher<VideoFrame, Never>
  public let onError: AnyPublisher<any Error, Never>
  public let logContext: LogContext
  private let dummy = LifecycleDummy {
    $0.addLabel(.videoCompressor)
  }

  private init(
    configuration: VideoCompressionConfiguration,
    compressionSession: VTCompressionSession,
  ) {
    self.configuration = configuration
    self.compressionSession = compressionSession
    compressedBuffer$ = PassthroughSubject<VideoFrame, Never>()
    error$ = PassthroughSubject<any Error, Never>()
    onCompressed = compressedBuffer$.eraseToAnyPublisher()
    onError = error$.eraseToAnyPublisher()
    logContext = LogContext {
      $0.addLabel(.videoCompressor)
    }
  }

  deinit {
    VTCompressionSessionInvalidate(compressionSession)
  }

  public func compress(_ frame: VideoFrame) {
    guard let imageBuf = frame.buffer.imageBuffer else {
      let context = logContext
      logger.warning("Cannot get img buf \(context.warning)")
      return
    }

    var flags: VTEncodeInfoFlags = []
    let imageOrientation = frame.imageOrientation
    let inputDeviceDirection = frame.inputDeviceDirection
    let status = VTCompressionSessionEncodeFrame(
      compressionSession,
      imageBuffer: imageBuf,
      presentationTimeStamp: frame.buffer.presentationTimeStamp,
      duration: frame.buffer.duration,
      frameProperties: nil,
      infoFlagsOut: &flags,
      outputHandler: { [weak self] status, flags, sampleBuffer in
        self?.processCompressorResult(
          sourceFrameRefCon: nil,
          status: status,
          infoFlags: flags,
          sampleBuffer: sampleBuffer,
          imageOrientation: imageOrientation,
          inputDeviceDirection: inputDeviceDirection,
        )
      }
    )
    if status != noErr {
      error$.send(AVMediaCodersError.framework(status))
    }
  }

  private func processCompressorResult(
    sourceFrameRefCon: UnsafeMutableRawPointer?,
    status: OSStatus,
    infoFlags: VTEncodeInfoFlags,
    sampleBuffer: CMSampleBuffer?,
    imageOrientation: ImageOrientation?,
    inputDeviceDirection: DeviceDirection?,
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
    #if DEBUG_MEDIA_DATA_IO
      let context = logContext.adding {
        $0.addLabels([.videoCodec, .debugMediaDataIO])
        $0["buffer"] = sampleBuffer.logContext
      }
      logger.trace("Compressed frame \(context.trace)")
    #endif
    compressedBuffer$.send(
      VideoFrame(
        buffer: sampleBuffer,
        imageOrientation: imageOrientation,
        inputDeviceDirection: inputDeviceDirection
      )
    )
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
          outputCallback: nil,
          refcon: nil,
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
    return VideoCompressor(configuration: configuration, compressionSession: session)
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

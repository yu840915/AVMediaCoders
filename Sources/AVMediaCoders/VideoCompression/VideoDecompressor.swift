import Combine
import VideoToolbox

private let logger = Loggers.decompressing.build()

final class VideoDecompressor {
  private(set) var decompressionSession: VTDecompressionSession!
  private let decompressedBuffer$ = PassthroughSubject<CMSampleBuffer, Never>()
  private let error$ = PassthroughSubject<Error, Never>()
  var onDecompressed: any Publisher<CMSampleBuffer, Never> { decompressedBuffer$ }
  var onError: any Publisher<Error, Never> { error$ }
}

extension VideoDecompressor {
  public static func create(formatDescription: CMVideoFormatDescription) throws -> VideoDecompressor
  {
    var session: VTDecompressionSession?
    let decompressor = VideoDecompressor()
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
      decompressionOutputRefCon: UnsafeMutableRawPointer?,
      sourceFrameRefCon: UnsafeMutableRawPointer?,
      status: OSStatus,
      flags: VTDecodeInfoFlags,
      buffer: CVImageBuffer?,
      presentationTimeStamp: CMTime,
      presentationDuration: CMTime
    ) in
    guard let pixelBuffer: CVPixelBuffer = buffer else {
      logger.warning("Cannot get pixel buffer")
      return
    }

    sourceFrameRefCon?.assumingMemoryBound(to: CVPixelBuffer.self).pointee = pixelBuffer
  }
}

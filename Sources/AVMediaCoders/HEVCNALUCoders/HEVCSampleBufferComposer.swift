import CoreMedia
import MPEGTransport

public class HEVCSampleBufferComposer {
  private var formatDescription: CMFormatDescription?
  private var formatDescriptionBuilder: HEVCFormatDescriptionBuilder?
  private(set) var dts: CMTime?
  private(set) var pts: CMTime?
  var frameID = 0

  public init() {}

  public func compose(
    from nalUnits: [HEVCNALUnit],
    pts: CMTime?,
    dts: CMTime?
  ) throws
    -> [CMSampleBuffer]
  {
    self.pts = pts
    self.dts = dts
    return try mergeSampleBuffers(from: nalUnits)
  }

  fileprivate func mergeSampleBuffers(
    from nalUnits: [HEVCNALUnit]
  ) throws -> [CMSampleBuffer] {
    if nalUnits.isEmpty {
      return []
    }
    let lastSliceIndex =
      nalUnits.firstIndex { $0.isFormatDescription }
      ?? nalUnits.endIndex
    let sliceNalus = Array(nalUnits[..<lastSliceIndex])

    if let formatDescription {
      return try merge(sliceNalus, formatDescription: formatDescription)
        + extractFormatDescription(from: Array(nalUnits[lastSliceIndex...]))
    } else {
      return try extractFormatDescription(from: Array(nalUnits[lastSliceIndex...]))
    }
  }
  fileprivate func merge(
    _ nalUnits: [HEVCNALUnit],
    formatDescription: CMFormatDescription,
  ) throws -> [CMSampleBuffer] {
    if nalUnits.isEmpty {
      return []
    }
    return try nalUnits.compactMap {
      try merge($0, formatDescription: formatDescription)
    }
  }

  fileprivate func merge(
    _ nalUnit: HEVCNALUnit,
    formatDescription: CMFormatDescription,
  ) throws
    -> CMSampleBuffer?
  {
    var bytes: [UInt8] = []
    let naluBytes = nalUnit.bytes
    bytes.append(contentsOf: UInt32(naluBytes.count).bigEndianBytes)
    bytes.append(contentsOf: naluBytes)
    var blockBuffer: CMBlockBuffer?
    try ensureSuccess(
      osStatus: CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: bytes.count,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: bytes.count,
        flags: 0,
        blockBufferOut: &blockBuffer
      )
    )
    guard let blockBuffer = blockBuffer else {
      throw AVMediaCodersError.missingBuffer
    }
    try ensureSuccess(
      osStatus: CMBlockBufferReplaceDataBytes(
        with: bytes,
        blockBuffer: blockBuffer,
        offsetIntoDestination: 0,
        dataLength: bytes.count
      )
    )

    var sampleBuffer: CMSampleBuffer?
    var size = CMBlockBufferGetDataLength(blockBuffer)
    var timingInfo = createIncreasingTimingInfo()
    try ensureSuccess(
      osStatus: CMSampleBufferCreateReady(
        allocator: kCFAllocatorDefault,
        dataBuffer: blockBuffer,
        formatDescription: formatDescription,
        sampleCount: 1,
        sampleTimingEntryCount: 1,
        sampleTimingArray: &timingInfo,
        sampleSizeEntryCount: 1,
        sampleSizeArray: &size,
        sampleBufferOut: &sampleBuffer
      )
    )
    guard let sampleBuffer = sampleBuffer else {
      throw AVMediaCodersError.missingBuffer
    }
    if nalUnit.isKeyFrame {
      let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DependsOnOthers).toOpaque()
      let value = Unmanaged.passUnretained(kCFBooleanFalse).toOpaque()
      sampleBuffer.configureAttachments {
        CFDictionarySetValue($0, key, value)
      }
    }
    return sampleBuffer
  }

  fileprivate func extractFormatDescription(from nalUnits: [HEVCNALUnit]) throws -> [CMSampleBuffer]
  {
    if nalUnits.isEmpty {
      return []
    }
    let lastFormatIndex =
      nalUnits.firstIndex { !$0.isFormatDescription }
      ?? nalUnits.endIndex
    let formatNalus = Array(nalUnits[..<lastFormatIndex])
    let builder = prepareBuilder()
    builder.add(formatNalus)
    if let format = try builder.build() {
      formatDescription = format
      formatDescriptionBuilder = nil
    }
    return try mergeSampleBuffers(from: Array(nalUnits[lastFormatIndex...]))
  }

  fileprivate func prepareBuilder() -> HEVCFormatDescriptionBuilder {
    if let formatDescriptionBuilder {
      return formatDescriptionBuilder
    }
    let builder = HEVCFormatDescriptionBuilder()
    formatDescriptionBuilder = builder
    return builder
  }

  private func createIncreasingTimingInfo() -> CMSampleTimingInfo {
    var timingInfo = CMSampleTimingInfo()
    timingInfo.decodeTimeStamp = dts ?? CMTime.invalid
    timingInfo.presentationTimeStamp =
      pts
      ?? CMTime(
        value: CMTimeValue(frameID * 20), timescale: CMTimeScale(600))
    timingInfo.duration = CMTime(value: CMTimeValue(20), timescale: CMTimeScale(600))
    frameID = frameID.advanced(by: 1)
    return timingInfo
  }
}

class HEVCFormatDescriptionBuilder {
  private var sps: HEVCNALUnit?
  private var pps: HEVCNALUnit?
  private var vps: HEVCNALUnit?
  private var seis: [HEVCNALUnit] = []

  func add(_ nalUnits: [HEVCNALUnit]) {
    nalUnits.forEach { add($0) }
  }

  func add(_ nalUnit: HEVCNALUnit) {
    switch nalUnit.header.type {
    case .sps:
      sps = nalUnit
    case .pps:
      pps = nalUnit
    case .vps:
      vps = nalUnit
    case .prefixSEI, .suffixSEI:
      seis.append(nalUnit)
    default:
      break
    }
  }

  func build() throws -> CMFormatDescription? {
    guard let sps = sps, let pps = pps else {
      return nil
    }
    var parameterSets: [[UInt8]] = []
    if let vps = vps {
      parameterSets.append(vps.bytes)
    }
    parameterSets =
      parameterSets + [sps.bytes, pps.bytes] + seis.map { $0.bytes }
    var formatDescription: CMFormatDescription?
    let parameterSetPointers = parameterSets.compactMap {
      $0.withUnsafeBufferPointer { $0 }.baseAddress
    }
    guard parameterSetPointers.count == parameterSets.count else {
      return nil
    }
    let parameterSetSizes = parameterSets.map { $0.count }
    try ensureSuccess(
      osStatus:
        CMVideoFormatDescriptionCreateFromHEVCParameterSets(
          allocator: kCFAllocatorDefault,
          parameterSetCount: parameterSets.count,
          parameterSetPointers: parameterSetPointers,
          parameterSetSizes: parameterSetSizes,
          nalUnitHeaderLength: 4,
          extensions: nil,
          formatDescriptionOut: &formatDescription
        )
    )
    return formatDescription
  }
}

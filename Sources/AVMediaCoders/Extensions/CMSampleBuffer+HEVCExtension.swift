import AVFoundation

extension CMSampleBuffer {
  func getHEVCParameterSets() throws -> [HEVCNALUnit]? {
    guard let formatDescription else {
      return nil
    }
    var count: Int = 0
    try ensureSuccess(
      osStatus: CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
        formatDescription,
        parameterSetIndex: 0,
        parameterSetPointerOut: nil,
        parameterSetSizeOut: nil,
        parameterSetCountOut: &count,
        nalUnitHeaderLengthOut: nil
      )
    )
    let nalus = try Array(0..<count).map {
      try getHEVCParameterSet(at: $0, from: formatDescription)
    }
    let datas = nalus.map { $0.bytes }
    let sizes = datas.map { $0.count }
    let pointer = datas.map {
      $0.withUnsafeBufferPointer { $0 }.baseAddress!
    }
    var formatDescriptionOut: CMFormatDescription?
    try ensureSuccess(
      osStatus: CMVideoFormatDescriptionCreateFromHEVCParameterSets(
        allocator: kCFAllocatorDefault,
        parameterSetCount: sizes.count,
        parameterSetPointers: pointer,
        parameterSetSizes: sizes,
        nalUnitHeaderLength: 4,
        extensions: nil,
        formatDescriptionOut: &formatDescriptionOut
      )
    )
    assert(formatDescriptionOut != nil)
    return nalus
  }

  private func getHEVCParameterSet(
    at index: Int,
    from description: CMFormatDescription
  ) throws
    -> HEVCNALUnit
  {
    var pointer: UnsafePointer<UInt8>?
    var size: Int = 0
    var headerLength: Int32 = 0
    try ensureSuccess(
      osStatus: CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
        description,
        parameterSetIndex: index,
        parameterSetPointerOut: &pointer,
        parameterSetSizeOut: &size,
        parameterSetCountOut: nil,
        nalUnitHeaderLengthOut: &headerLength
      )
    )
    guard let pointer else {
      throw AVMediaCodersError.missingBuffer
    }
    let retVal = try HEVCNALUnit(bytes: [UInt8](Data(bytes: pointer, count: size)))
    assert(retVal.bytes == [UInt8](Data(bytes: pointer, count: size)))
    return retVal
  }

  func getHEVCDataNALUnits() throws -> [HEVCNALUnit] {
    guard let dataBuffer else {
      throw AVMediaCodersError.missingBuffer
    }
    var bufPtr: UnsafeMutablePointer<Int8>?
    var bufSize: Int = 0
    try ensureSuccess(
      osStatus: CMBlockBufferGetDataPointer(
        dataBuffer,
        atOffset: 0,
        lengthAtOffsetOut: nil,
        totalLengthOut: &bufSize,
        dataPointerOut: &bufPtr
      )
    )
    guard let bufPtr else {
      throw AVMediaCodersError.missingBuffer
    }
    var nalus: [HEVCNALUnit] = []
    var offset = 0
    let bufBytes = [Int8](UnsafeMutableBufferPointer<Int8>(start: bufPtr, count: bufSize))
      .map { UInt8(bitPattern: $0) }

    while offset < bufSize {
      // Read the NALU length (4 bytes)
      let lenBytes = [UInt8](bufBytes[offset..<offset + 4])
      let naluLength = try UInt32(bigEndianBytes: lenBytes)
      offset += 4
      // Read the NALU data

      nalus.append(
        try HEVCNALUnit(
          bytes: Array(
            bufBytes[offset..<offset + Int(naluLength)]
          )
        )
      )
      offset += Int(naluLength)
    }
    return nalus
  }
}

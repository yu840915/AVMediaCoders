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
    return try Array(0..<count).map { try getHEVCParameterSet(at: $0, from: formatDescription) }
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
    return try HEVCNALUnit(bytes: [UInt8](Data(bytes: pointer, count: size)))
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

    while offset < bufSize {
      // Read the NALU length (4 bytes)
      var naluLength: UInt32 = 0
      memcpy(&naluLength, bufPtr + offset, 4)
      naluLength = CFSwapInt32BigToHost(naluLength)  // Convert to host byte order
      offset += 4

      // Read the NALU data

      let naluData = Data(bytes: bufPtr + offset, count: Int(naluLength))
      nalus.append(try HEVCNALUnit(bytes: [UInt8](naluData)))
      offset += Int(naluLength)
    }
    return nalus
  }
}

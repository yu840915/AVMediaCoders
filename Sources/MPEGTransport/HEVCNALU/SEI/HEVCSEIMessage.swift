import Foundation

/// Standard SEI payload types defined in ITU-T H.265
public enum HEVCSEIPayloadType: UInt32, Equatable, Sendable {
  case buffingPeriod = 0
  case picTiming = 1
  case panScanRect = 2
  case fillerPayload = 3
  case userDataRegisteredItuTT35 = 4
  case userDataUnregistered = 5
  case recoveryPoint = 6
  case sceneInfo = 9
  case fullFrameSnapshot = 15
  case progressiveRefinementSegmentStart = 16
  case progressiveRefinementSegmentEnd = 17
  case filmGrainCharacteristics = 19
  case postFilterHint = 22
  case toneMappingInfo = 23
  case framePackingArrangement = 45
  case displayOrientation = 47
  case greenMetadata = 56
  case structureOfPicturesInfo = 128
  case activeParameterSets = 129
  case decodingUnitInfo = 130
  case temporalSubLayerZeroIndex = 131
  case decodedPictureHash = 132
  case scalableNesting = 133
  case regionRefreshInfo = 134
  case noDisplay = 135
  case timeCode = 136
  case masteringDisplayColourVolume = 137
  case segmentedRectFramePacking = 138
  case temporalMotionConstrainedTileSet = 139
  case chromaResamplingFilterHint = 140
  case kneeFunction = 141
  case colourRemappingInfo = 142
  case deinterlacingFieldIdentification = 143
  case contentLightLevel = 144
  case dependentRapIndication = 145
  case codedRegionCompletion = 146
  case alternativeTransferCharacteristics = 147
  case ambientViewingEnvironment = 148
  case contentColourVolume = 149
  case equirectangularProjection = 150
  case cubeMapProjection = 151
  case fisheyeVideoInfo = 152
  case sphereRotation = 154
  case omniViewportInfo = 156
  case cubemapOmniViewport = 157
  case regionWisePacking = 155
  case regionalNesting = 158
  case mctsFoPMetadata = 159
}

public struct HEVCSEIMessage: Sendable, Equatable {
  public let payloadType: HEVCSEIPayloadType
  public let payload: [UInt8]

  public init(payloadType: HEVCSEIPayloadType, payload: [UInt8]) {
    self.payloadType = payloadType
    self.payload = payload
  }

  public var bytes: [UInt8] {
    var result: [UInt8] = []
    result.append(contentsOf: variableLengthBytes(for: UInt32(payloadType.rawValue)))
    result.append(contentsOf: variableLengthBytes(for: UInt32(payload.count)))
    result.append(contentsOf: payload)
    return result
  }

  @inline(__always)
  func variableLengthBytes(for value: UInt32) -> [UInt8] {
    var bytes: [UInt8] = []
    var remaining = value
    while remaining >= 255 {
      bytes.append(0xFF)
      remaining -= 255
    }
    bytes.append(UInt8(remaining))
    return bytes
  }
}

extension HEVCNALUnit {
  public static func withSEIMessages(
    _ messages: [HEVCSEIMessage],
    isPrefix: Bool = true,
  ) -> HEVCNALUnit {
    var payload: [UInt8] = []
    for message in messages {
      payload.append(contentsOf: message.bytes)
    }
    // Add RBSP trailing bits (bit 1 followed by zeros to byte-align)
    payload.append(0x80)

    return HEVCNALUnit(
      header: HEVCNALUnitHeader(
        type: isPrefix ? .prefixSEI : .suffixSEI,
        layerID: 0,
        temporalIDPlus1: 1
      ),
      payload: payload,
    )
  }

  public var seiMessages: [HEVCSEIMessage] {
    guard header.type == .prefixSEI || header.type == .suffixSEI else { return [] }
    var messages: [HEVCSEIMessage] = []
    var offset = 0

    while offset < payload.count {
      // Check for RBSP trailing bits
      if payload[offset] == 0x80 {
        break
      }

      // Parse payload type
      var payloadType: UInt32 = 0
      while offset < payload.count && payload[offset] == 0xFF {
        payloadType += 255
        offset += 1
      }
      guard
        offset < payload.count
      else {
        return []
      }
      payloadType += UInt32(payload[offset])
      guard
        let payloadType = HEVCSEIPayloadType(rawValue: payloadType)
      else {
        return []
      }
      offset += 1

      // Parse payload size
      var payloadSize: UInt32 = 0
      while offset < payload.count && payload[offset] == 0xFF {
        payloadSize += 255
        offset += 1
      }
      guard
        offset < payload.count
      else {
        return []
      }
      payloadSize += UInt32(payload[offset])
      offset += 1

      // Extract payload
      guard
        offset + Int(payloadSize) <= payload.count
      else {
        return []
      }
      let messagePayload = Array(payload[offset..<(offset + Int(payloadSize))])
      offset += Int(payloadSize)

      messages.append(HEVCSEIMessage(payloadType: payloadType, payload: messagePayload))
    }

    return messages
  }
}

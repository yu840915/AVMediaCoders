/// Content Light Level Info SEI (payload type 144)
public struct HEVCContentLightLevelSEI: Sendable, Equatable {
  /// Maximum Content Light Level (cd/m²)
  public let maxContentLightLevel: UInt16
  /// Maximum Frame-average Light Level (cd/m²)
  public let maxPicAverageLightLevel: UInt16

  public init(maxContentLightLevel: UInt16, maxPicAverageLightLevel: UInt16) {
    self.maxContentLightLevel = maxContentLightLevel
    self.maxPicAverageLightLevel = maxPicAverageLightLevel
  }

  public init?(payload: [UInt8]) {
    guard payload.count >= 4 else { return nil }
    self.maxContentLightLevel = UInt16(payload[0]) << 8 | UInt16(payload[1])
    self.maxPicAverageLightLevel = UInt16(payload[2]) << 8 | UInt16(payload[3])
  }

  public func toSEIMessage() -> HEVCSEIMessage {
    var payload: [UInt8] = []
    payload.append(UInt8(maxContentLightLevel >> 8))
    payload.append(UInt8(maxContentLightLevel & 0xFF))
    payload.append(UInt8(maxPicAverageLightLevel >> 8))
    payload.append(UInt8(maxPicAverageLightLevel & 0xFF))
    return HEVCSEIMessage(payloadType: .contentLightLevel, payload: payload)
  }
}

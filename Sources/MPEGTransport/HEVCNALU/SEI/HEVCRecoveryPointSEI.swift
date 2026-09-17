/// Recovery Point SEI (payload type 6)
public struct HEVCRecoveryPointSEI: Sendable, Equatable {
  public let recoveryPocCount: Int32
  public let exactMatchFlag: Bool
  public let brokenLinkFlag: Bool

  public init(recoveryPocCount: Int32, exactMatchFlag: Bool, brokenLinkFlag: Bool) {
    self.recoveryPocCount = recoveryPocCount
    self.exactMatchFlag = exactMatchFlag
    self.brokenLinkFlag = brokenLinkFlag
  }

  public func toSEIMessage() -> HEVCSEIMessage {
    // Simplified: encode as signed exp-golomb + flags
    var payload: [UInt8] = []
    // This is a simplified encoding; real implementation needs exp-golomb
    let signedValue = recoveryPocCount >= 0 ? recoveryPocCount * 2 : (-recoveryPocCount * 2) - 1
    payload.append(UInt8(truncatingIfNeeded: signedValue))
    var flags: UInt8 = 0
    if exactMatchFlag { flags |= 0x80 }
    if brokenLinkFlag { flags |= 0x40 }
    payload.append(flags)
    return HEVCSEIMessage(payloadType: .recoveryPoint, payload: payload)
  }
}

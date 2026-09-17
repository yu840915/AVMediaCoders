import Foundation

/// User Data Unregistered SEI message (payload type 5)
/// Used for custom application-specific data with a UUID identifier
public struct HEVCUserDataUnregisteredSEI: Sendable, Equatable {
  /// 16-byte UUID identifying the application/vendor
  public let uuid: UUID
  /// Application-specific payload data
  public let userData: [UInt8]

  public init(uuid: UUID, userData: [UInt8]) {
    self.uuid = uuid
    self.userData = userData
  }

  /// Parse from raw SEI payload
  public init?(payload: [UInt8]) {
    guard payload.count >= 16 else { return nil }
    let uuidBytes = Array(payload.prefix(16))
    guard let uuid = UUID(bytes: uuidBytes) else { return nil }
    self.uuid = uuid
    self.userData = Array(payload.dropFirst(16))
  }

  /// Serialize to SEI message
  public func toSEIMessage() -> HEVCSEIMessage {
    var payload: [UInt8] = []
    payload.append(contentsOf: uuid.bytes)
    payload.append(contentsOf: userData)
    return HEVCSEIMessage(payloadType: .userDataUnregistered, payload: payload)
  }
}

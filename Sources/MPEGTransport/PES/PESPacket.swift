import CoreMedia

public struct PESPacket: Equatable, Sendable {
  let header: PESHeader
  public let payload: [UInt8]
  public var bytes: [UInt8] { header.bytes + payload }
  public var pts: CMTime? { header.type.pts }
  public var dts: CMTime? { header.type.dts }

  public init(streamType: PESHeader.StreamType, payload: [UInt8] = []) {
    self.header = PESHeader(type: streamType, payloadLength: UInt16(payload.count))
    self.payload = payload
  }

  init(bytes: [UInt8]) throws {
    header = try PESHeader(bytes: bytes)
    guard header.payloadLength <= bytes.count - header.bytes.count else {
      throw MPEGTransportError.bufferTooShort
    }
    payload = Array(
      bytes.dropFirst(header.bytes.count).prefix(Int(header.payloadLength))
    )
  }
}

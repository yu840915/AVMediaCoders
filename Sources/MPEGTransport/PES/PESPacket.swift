import LogContext

public struct PESPacket: Equatable, Sendable, LogContextReadable {
  let header: PESHeader
  public let payload: [UInt8]
  public var bytes: [UInt8] { header.bytes + payload }
  public var pts: MediaTimestamp? { header.type.pts }
  public var dts: MediaTimestamp? { header.type.dts }

  public var logContext: LogContext {
    LogContext {
      $0["header"] = header.logContext
      $0["payloadLength"] = payload.count
    }
  }

  public init(streamType: PESHeader.StreamType, payload: [UInt8] = []) {
    self.header = PESHeader(type: streamType, payloadLength: payload.count)
    self.payload = payload
  }

  init(bytes: [UInt8]) throws {
    header = try PESHeader(bytes: bytes)
    let body = bytes.dropFirst(header.bytes.count)

    func handleBounded(with payloadLength: Int) {

    }
    func handleUnbounded() {

    }

    if let payloadLength = header.payloadLength {  //Bounded
      guard payloadLength >= 0 else {
        throw MPEGTransportError.invalidPES(.invalidPacketLength)
      }
      guard payloadLength <= body.count else {
        throw MPEGTransportError.bufferTooShort
      }
      payload = Array(body.prefix(payloadLength))
    } else {  //Unbounded
      payload = Array(body)
    }
  }
}

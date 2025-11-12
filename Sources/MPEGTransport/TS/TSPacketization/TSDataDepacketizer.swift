private let logger = MPEGLoggers.tsDepacketizing.build()

class TSDataDepacketizer {
  let PID: TSPID
  private(set) var stashedPackets: [TSPacket] = []

  init(pid: TSPID) {
    self.PID = pid
  }

  func feed(_ packets: [TSPacket]) -> [Output] {
    return packets.compactMap(feed)
  }

  func feed(_ packet: TSPacket) -> Output? {
    guard packet.header.pid == PID.value else {
      return nil
    }
    if packet.header.isStartOfPayload {
      let output = flush()
      stashedPackets.append(packet)
      return output
    } else if !stashedPackets.isEmpty {
      stashedPackets.append(packet)
      return nil
    } else {
      return nil
    }
  }

  func flush() -> Output? {
    guard !stashedPackets.isEmpty else { return nil }
    defer {
      stashedPackets.removeAll()
    }
    do {
      var counter = stashedPackets[0].header.continuityCounter
      let esData = try stashedPackets.reduce(into: [UInt8]()) { result, packet in
        guard packet.header.continuityCounter == counter else {
          throw MPEGTransportError.invalidTS(.discountinuityDetected)
        }
        counter = (counter + 1) & 0x0F
        result.append(contentsOf: packet.payload.dataPayload)
      }
      if esData.isEmpty {
        return nil
      }
      return Output(
        esData: esData,
        adaptationField: stashedPackets[0].payload.adaptationField
      )
    } catch {
      logger.warning("Error detected: \(error)")
      return nil
    }
  }

}

extension TSDataDepacketizer {
  struct Output: Equatable {
    let esData: [UInt8]
    let adaptationField: TSAdaptationField?
  }
}

actor TSESDepacketizer {
  let pid: TSPID
  private(set) var stashedPackets: [TSPacket] = []

  init(pid: TSPID) {
    self.pid = pid
  }

  func feed(_ packets: [TSPacket]) -> [Output] {
    return packets.compactMap(feed)
  }

  func feed(_ packet: TSPacket) -> Output? {
    guard packet.header.pid == pid.value else {
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
    return Output(
      esData: stashedPackets.reduce(into: [UInt8]()) { result, packet in
        result.append(contentsOf: packet.payload.dataPayload)
      },
      adaptationField: stashedPackets[0].payload.adaptationField
    )
  }

}

extension TSESDepacketizer {
  struct Output: Equatable {
    let esData: [UInt8]
    let adaptationField: TSAdaptationField?
  }
}

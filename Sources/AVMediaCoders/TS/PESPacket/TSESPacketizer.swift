actor TSESPacketizer {
  let PID: TSPID
  private(set) var continuityCounter: UInt8

  init(pid: TSPID, continuityCounter: UInt8 = 0) {
    self.continuityCounter = continuityCounter
    self.PID = pid
  }

  func packetize(
    adaptationFieldConfiguration afConfig: TSPacket.AdaptationFieldConfiguration?,
    esData: [UInt8]
  ) -> [TSPacket] {
    var packets: [TSPacket] = []
    var remainingData = esData
    var isStartOfPayload = true
    while !remainingData.isEmpty {
      let packet = TSPacket(
        PID: PID,
        continuityCounter: continuityCounter,
        isStartOfPayload: isStartOfPayload,
        adaptationFieldConfiguration: isStartOfPayload ? afConfig : nil,
        data: remainingData
      )
      packets.append(packet)
      isStartOfPayload = false
      continuityCounter = (continuityCounter + 1) & 0x0F
      remainingData = Array(remainingData[(packet.payload.dataPayloadLength)...])
    }
    return packets
  }

  func createPaddings(count: Int = 1) -> [TSPacket] {
    return Array(
      repeating: TSPacket(
        PID: PID,
        continuityCounter: continuityCounter,
        isStartOfPayload: true,
        adaptationFieldConfiguration: nil,
        data: []
      ),
      count: count
    )
  }
}

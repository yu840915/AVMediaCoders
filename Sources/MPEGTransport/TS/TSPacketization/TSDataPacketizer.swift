import LogContext

private let logger = Loggers.muxing.build()

class TSDataPacketizer {
  let PID: TSPID
  private(set) var continuityCounter: UInt8

  init(pid: TSPID, continuityCounter: UInt8 = 0) {
    self.continuityCounter = continuityCounter
    self.PID = pid
  }

  func packetize(sectionData: [UInt8]) -> [TSPacket] {
    packetize(adaptationFieldConfiguration: nil, data: sectionData)
  }

  func packetize(
    adaptationFieldConfiguration afConfig: TSPacket.AdaptationFieldConfiguration?,
    esData: [UInt8]
  ) -> [TSPacket] {
    packetize(
      adaptationFieldConfiguration: afConfig,
      data: esData
    )
  }

  func packetize(
    adaptationFieldConfiguration afConfig: TSPacket.AdaptationFieldConfiguration? = nil,
    data: [UInt8]
  ) -> [TSPacket] {
    var packets: [TSPacket] = []
    var remainingData = data
    var isStartOfPayload = true
    while !remainingData.isEmpty {
      let packet = TSPacket(
        PID: PID,
        continuityCounter: continuityCounter,
        isStartOfPayload: isStartOfPayload,
        adaptationFieldConfiguration: isStartOfPayload ? afConfig : nil,
        data: remainingData
      )
      #if DEBUG_PACKETIZATION_IO
        let context = packet.logContext.adding {
          $0.addLabel(.debugPacketizationIO)
        }
        logger.debug("Packetized TS Packet \(context.debug)")
      #endif
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

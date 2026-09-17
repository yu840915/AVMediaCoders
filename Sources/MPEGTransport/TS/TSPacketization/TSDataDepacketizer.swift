import DebugToolkit
import LogContext

private let logger = Loggers.tsDepacketizing.build()

class TSDataDepacketizer: LogContextReadable {
  let PID: TSPID
  private(set) var stashedPackets: [TSPacket] = []
  private(set) var logContext: LogContext
  private let dummy = LifecycleDummy {
    $0.addLabel("Depacketizer")
  }

  init(
    pid: TSPID,
    logContextBuilder: StructBuilder<LogContext>? = nil
  ) {
    self.PID = pid
    logContext = LogContext {
      logContextBuilder?(&$0)
      $0[.id] = "\(pid)"
      $0.addLabel("Depacketizer")
    }
  }

  func feed(_ packets: [TSPacket]) -> [Output] {
    return packets.compactMap(feed)
  }

  func feed(_ packet: TSPacket) -> Output? {
    guard packet.header.pid == PID.value else {
      return nil
    }
    var context = logContext.adding {
      $0.setDebugDetail {
        $0["packet"] = packet.logContext
      }
    }
    defer {
      logContext["stashed"] = "\(stashedPackets.count)"
    }
    if packet.header.isStartOfPayload {
      #if DEBUG_PACKETIZATION_IO
        context.addLabel(.debugPacketizationIO)
        logger.debug("Handled Packet, should flush \(context.debug)")
      #endif
      let output = flush()
      stashedPackets.append(packet)
      return output
    } else if !stashedPackets.isEmpty {
      #if DEBUG_PACKETIZATION_IO
        context.addLabel(.debugPacketizationIO)
        logger.debug("Handled Packet, should append \(context.debug)")
      #endif
      stashedPackets.append(packet)
      return nil
    } else {
      #if DEBUG_PACKETIZATION_IO
        context.addLabel(.debugPacketizationIO)
        logger.notice("Handled Packet, should skip \(context.notice)")
      #endif
      return nil
    }
  }

  func flush() -> Output? {
    var context = logContext
    guard !stashedPackets.isEmpty else {
      #if DEBUG_PACKETIZATION_IO
        context.addLabel(.debugPacketizationIO)
        context["reason"] = "no stashed packets"
        logger.trace("Nothing to flush \(context.trace)")
      #endif
      return nil
    }
    defer {
      stashedPackets.removeAll()
      logContext["stashed"] = "\(stashedPackets.count)"
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
        #if DEBUG_PACKETIZATION_IO
          context.addLabel(.debugPacketizationIO)
          context["reason"] = "empty ES data"
          logger.trace("Nothing to flush \(context.trace)")
        #endif
        return nil
      }
      #if DEBUG_PACKETIZATION_IO
        context.addLabel(.debugPacketizationIO)
        context["esDataSize"] = esData.count.formattedSize
        logger.debug("Flushed \(context.debug)")
      #endif
      return Output(
        esData: esData,
        adaptationField: stashedPackets[0].payload.adaptationField
      )
    } catch {
      let context = logContext.adding {
        $0.setError(error)
        $0["counters"] = stashedPackets
          .map { "\($0.header.continuityCounter)" }
          .joined(separator: ",")
        $0["starts"] = stashedPackets
          .map { $0.header.isStartOfPayload ? "1" : "0" }
          .joined()
      }
      logger.warning("Failed to flush \(context.warning)")
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

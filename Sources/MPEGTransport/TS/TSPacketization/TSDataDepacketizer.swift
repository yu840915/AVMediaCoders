import LogContext

private let logger = Loggers.tsDepacketizing.build()

class TSDataDepacketizer: LogContextReading {
  let PID: TSPID
  private(set) var stashedPackets: [TSPacket] = []
  private(set) var logContext: LogContext

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
    let context = logContext
    logger.info("Initialized  \(context.info)")
  }

  func feed(_ packets: [TSPacket]) -> [Output] {
    return packets.compactMap(feed)
  }

  func feed(_ packet: TSPacket) -> Output? {
    guard packet.header.pid == PID.value else {
      return nil
    }
    defer {
      logContext["stashed"] = "\(stashedPackets.count)"
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
    var context = logContext
    guard !stashedPackets.isEmpty else {
      context["reason"] = "no stashed packets"
      logger.trace("Nothing to flush \(context.trace)")
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
        context["reason"] = "empty ES data"
        logger.trace("Nothing to flush \(context.trace)")
        return nil
      }
      context["esDataSize"] = "\(esData.count)"
      logger.debug("Flushed \(context.debug)")
      return Output(
        esData: esData,
        adaptationField: stashedPackets[0].payload.adaptationField
      )
    } catch {
      let context = logContext.adding {
        $0.setError(error)
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

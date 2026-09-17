import CoreMedia
import LogContext
import MPEGTransport

private let logger = Loggers.packetizing.build()

public class VideoDepacketizer {
  let sampleBufferComposer: HEVCSampleBufferComposer = HEVCSampleBufferComposer()
  private var ptsConverter = RelativeMediaTimestampConverter(
    strategy: .startFromZero
  )

  public init() {}

  public func depacketize(_ packet: PESPacket) throws -> [VideoFrame] {
    do {
      #if DEBUG_PACKETIZATION_IO
        logPES(packet)
      #endif
      let nalu = try HEVCNALUnit(bytes: packet.payload)
      #if DEBUG_PACKETIZATION_IO
        logNALU(nalu)
      #endif
      var pts: MediaTimestamp?
      if let packetPTS = packet.pts {
        pts = ptsConverter.convert(packetPTS)
      }
      return try sampleBufferComposer.compose(
        from: [nalu],
        pts: pts?.cmTime,
        dts: packet.dts?.cmTime,
      )
    } catch {
      let context = LogContext {
        $0.addLabel(.debugPacketizationIO)
        $0.setError(error)
      }
      logger.warning("Cannot depacketize \(context.warning)")
      throw error
    }
  }

  @inline(__always)
  private func logPES(_ packet: PESPacket) {
    let context = packet.logContext.adding {
      $0.addLabel(.debugPacketizationIO)
    }
    logger.debug("Depacketize PES Packet \(context.debug)")
  }

  @inline(__always)
  private func logNALU(_ nalu: HEVCNALUnit) {
    let context = nalu.logContext.adding {
      $0.addLabel(.debugPacketizationIO)
    }
    logger.debug("Extracted NALU \(context.debug)")
  }
}

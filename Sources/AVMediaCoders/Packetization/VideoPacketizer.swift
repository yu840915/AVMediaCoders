import CoreMedia
import MPEGTransport

private let logger = Loggers.packetizing.build()

public final class VideoPacketizer: Sendable {
  public init() {}
  let decomposer: HEVCSampleBufferDecomposer = HEVCSampleBufferDecomposer()

  public func packetize(_ videoFrame: VideoFrame, streamID: UInt8 = 0) throws -> [PESPacket] {
    let buffer = videoFrame.buffer
    let nalus = try decomposer.decompose(videoFrame)
    let ptsDts = PESHeaderExtension.PtsAndDts(
      pts: buffer.presentationTimeStamp.videoTimestamp,
      dts: buffer.decodeTimeStamp.videoTimestamp,
    )
    #if DEBUG_PACKETIZATION_IO
      logNALUs(nalus, streamID: streamID)
    #endif
    return nalus.map {
      let pes = PESPacket(
        streamType: .video(
          streamID: streamID,
          extension: .init(ptsAndDts: ptsDts)
        ),
        payload: $0.bytes
      )
      #if DEBUG_PACKETIZATION_IO
        logPES(pes)
      #endif
      return pes
    }
  }

  @inline(__always)
  private func logPES(_ packet: PESPacket) {
    let context = packet.logContext.adding {
      $0.addLabel(.debugPacketizationIO)
    }
    logger.debug("Packetize PES Packet \(context.debug)")
  }

  @inline(__always)
  private func logNALUs(_ nalus: [HEVCNALUnit], streamID: UInt8) {
    for nalu in nalus {
      let context = nalu.logContext.adding {
        $0.addLabel(.debugPacketizationIO)
        $0["streamID"] = "\(streamID)"
      }
      logger.debug("Produced NALU \(context.debug)")
    }
  }
}

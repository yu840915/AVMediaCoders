import CoreMedia

public class VideoDepacketizer {
  let sampleBufferComposer: HEVCSampleBufferComposer = HEVCSampleBufferComposer()

  public init() {}

  public func depacketize(_ packet: PESPacket) throws -> [CMSampleBuffer] {
    let nalu = try HEVCNALUnit(bytes: packet.payload)
    return try sampleBufferComposer.compose(
      from: [nalu],
      pts: packet.pts,
      dts: packet.dts
    )
  }
}

import CoreMedia

class VideoPacketizer {

  let decomposer: HEVCSampleBufferDecomposer = HEVCSampleBufferDecomposer()

  func packetize(_ videoBuffer: CMSampleBuffer, streamID: UInt8 = 0) throws -> [PESPacket] {
    let nalus = try decomposer.decompose(videoBuffer)
    let ptsDts = PESHeaderExtension.PtsAndDts(
      pts: videoBuffer.presentationTimeStamp, dts: videoBuffer.decodeTimeStamp
    )
    return nalus.map {
      PESPacket(
        streamType: .video(
          streamID: streamID,
          extension: .init(ptsAndDts: ptsDts)
        ),
        payload: $0.bytes
      )
    }
  }
}

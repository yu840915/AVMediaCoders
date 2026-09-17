import CoreMedia
import MPEGTransport

public final class HEVCSampleBufferDecomposer: Sendable {
    public init() {}

    public func decompose(_ videoFrame: VideoFrame) throws -> [HEVCNALUnit] {
        let sampleBuffer = videoFrame.buffer
        var nalus = [HEVCNALUnit]()
        if let seiNalue = HEVCNALUnit.withDeviceMotion(
            deviceDirection: videoFrame.inputDeviceDirection,
            imageOrientation: videoFrame.imageOrientation,
        ) {
            nalus.append(seiNalue)
        }
        nalus.append(contentsOf: try sampleBuffer.getHEVCDataNALUnits())
        if sampleBuffer.containsKeyFrame,
            let paramSetNalus = try sampleBuffer.getHEVCParameterSets()
        {
            return paramSetNalus + nalus
        }
        return nalus
    }
}

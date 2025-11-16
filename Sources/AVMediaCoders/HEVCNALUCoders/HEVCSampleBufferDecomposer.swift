import CoreMedia
import MPEGTransport

public final class HEVCSampleBufferDecomposer: Sendable {
    public init() {}

    public func decompose(_ sampleBuffer: CMSampleBuffer) throws -> [HEVCNALUnit] {
        let dataNalus = try sampleBuffer.getHEVCDataNALUnits()
        if sampleBuffer.containsKeyFrame,
            let paramSetNalus = try sampleBuffer.getHEVCParameterSets()
        {
            return paramSetNalus + dataNalus
        }
        return dataNalus
    }
}

import AVFoundation

public class HEVCNALUnitSerializer {
    public init() {}

    public func split(from sampleBuffer: CMSampleBuffer) throws -> [HEVCNALUnit] {        
        let dataNalus = try sampleBuffer.getHEVCDataNALUnits()
        if sampleBuffer.containsKeyFrame,
            let paramSetNalus = try sampleBuffer.getHEVCParameterSets()
        {
            return paramSetNalus + dataNalus
        }
        return dataNalus
    }
}

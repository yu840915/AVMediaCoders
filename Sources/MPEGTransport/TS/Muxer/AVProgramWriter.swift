public enum VideoType: Sendable {
    case mpeg1
    case mpeg2
    case avc
    case hevc

    var streamType: TSStreamType {
        switch self {
        case .mpeg1: .videoMPEG1
        case .mpeg2: .videoMPEG2
        case .avc: .videoAVC
        case .hevc: .videoHEVC
        }
    }
}

public enum AudioType: Sendable {
    case mpeg1
    case mpeg2
    case aac
    case dolbyDigital

    var streamType: TSStreamType {
        switch self {
        case .mpeg1: .audioMPEG1
        case .mpeg2: .audioMPEG2HalvedSampleRate
        case .aac: .audioADTSAAC
        case .dolbyDigital: .audioATSCDolbyDigital
        }
    }
}

public final class AVProgramWriter: Sendable {
    public let videoStreamPID: TSPID
    public let audioStreamPID: TSPID
    public let programInfo: [UInt8]
    public let videoType: VideoType
    public let audioType: AudioType
    let muxer: TSMuxer

    init(
        videoStreamPID: TSPID,
        audioStreamPID: TSPID,
        programInfo: [UInt8],
        videoType: VideoType,
        audioType: AudioType,
        muxer: TSMuxer
    ) {
        self.videoStreamPID = videoStreamPID
        self.audioStreamPID = audioStreamPID
        self.programInfo = programInfo
        self.videoType = videoType
        self.audioType = audioType
        self.muxer = muxer
    }

    public func sendVideoData(
        _ esData: [UInt8],
        adaptationFieldConfiguration: TSPacket.AdaptationFieldConfiguration? = nil
    ) async throws {
        try await muxer.send(
            adaptationFieldConfiguration: adaptationFieldConfiguration,
            esData: esData,
            forPID: videoStreamPID,
        )
    }

    public func sendVideoPackets(
        _ packets: [PESPacket],
        adaptationFieldConfiguration: TSPacket.AdaptationFieldConfiguration? = nil
    ) async throws {
        for packet in packets {
            try await sendVideoData(
                packet.bytes,
                adaptationFieldConfiguration: adaptationFieldConfiguration,
            )
        }
    }

    public func sendAudioData(
        _ esData: [UInt8],
        adaptationFieldConfiguration: TSPacket.AdaptationFieldConfiguration? = nil
    ) async throws {
        try await muxer.send(
            adaptationFieldConfiguration: adaptationFieldConfiguration,
            esData: esData,
            forPID: audioStreamPID,
        )
    }

    public func sendAudioPackets(
        _ packets: [PESPacket],
        adaptationFieldConfiguration: TSPacket.AdaptationFieldConfiguration? = nil
    ) async throws {
        for packet in packets {
            try await sendAudioData(
                packet.bytes,
                adaptationFieldConfiguration: adaptationFieldConfiguration,
            )
        }
    }
}

extension TSMuxer {
    public func buildAVProgram(
        programInfo: [UInt8],
        videoType: VideoType,
        audioType: AudioType
    ) throws -> AVProgramWriter {
        var videoPID = TSPID.nullPacket
        var audioPID = TSPID.nullPacket
        try buildProgram(
            withNumberOfDataStreams: 2
        ) { streams in
            videoPID = streams[0]
            audioPID = streams[1]
            return TSProgramMapTable.Parameters(
                PCRPID: videoPID,
                programInfo: programInfo,
                programElementInfos: [
                    TSProgramElementInfo(
                        streamType: videoType.streamType,
                        elementaryPID: videoPID,
                        ESInfo: []
                    ),
                    TSProgramElementInfo(
                        streamType: audioType.streamType,
                        elementaryPID: audioPID,
                        ESInfo: []
                    ),
                ]
            )
        }
        return AVProgramWriter(
            videoStreamPID: videoPID,
            audioStreamPID: audioPID,
            programInfo: programInfo,
            videoType: videoType,
            audioType: audioType,
            muxer: self
        )
    }
}

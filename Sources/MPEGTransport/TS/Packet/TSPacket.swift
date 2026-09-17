import LogContext

public struct TSPacket: Equatable, Sendable, LogContextReadable {
    let packetSize = 188
    let headerSize = 4
    let payloadSize = 184
    let header: TSHeader
    let payload: Payload

    public var bytes: [UInt8] { header.bytes + payload.bytes }

    public var logContext: LogContext {
        LogContext {
            $0["header"] = header.logContext
            $0["payload"] = payload.logContext
        }
    }

    init(
        PID: TSPID,
        continuityCounter: UInt8,
        isStartOfPayload: Bool = false,
        adaptationFieldConfiguration afConfig: AdaptationFieldConfiguration? = nil,
        data: [UInt8] = []
    ) {
        let needsAF = afConfig != nil || data.count < payloadSize
        let hasData = !data.isEmpty
        if needsAF {
            let af = TSAdaptationField(
                remainingDataLength: data.count,
                pcr: afConfig?.pcr,
                opcr: afConfig?.opcr,
                randomAccessIndicator: afConfig?.allowRandomAccess ?? false
            )
            payload =
                hasData
                ? .both(af, Array(data.prefix(payloadSize - Int(af.length) - 1)))
                : .adaptationField(af)
        } else {
            payload = .dataPayload(Array(data.prefix(payloadSize)))
        }
        header = TSHeader(
            isStartOfPayload: isStartOfPayload,
            PID: PID,
            adaptationFieldControl: payload.adaptationFieldControl,
            continuityCounter: continuityCounter
        )
    }

    public init(bytes: [UInt8]) throws {
        guard bytes.count >= packetSize else {
            throw MPEGTransportError.bufferTooShort
        }
        header = try TSHeader(bytes: Array(bytes[0..<headerSize]))

        payload = try Payload(
            adaptationFieldControl: header.adaptationFieldControl,
            data: Array(bytes[headerSize..<packetSize])
        )
    }
}

extension TSPacket {
    enum Payload: Equatable, Sendable, LogContextReadable {
        case adaptationField(TSAdaptationField)
        case dataPayload([UInt8])
        case both(TSAdaptationField, [UInt8])

        public var logContext: LogContext {
            LogContext {
                $0["dataLength"] = dataPayloadLength
                switch self {
                case .adaptationField(let field):
                    $0["type"] = "AdaptationField"
                    $0["adaptationField"] = field.logContext
                case .dataPayload(_):
                    $0["type"] = "ESData"
                case .both(let field, _):
                    $0["type"] = "AdaptationField&ESData"
                    $0["adaptationField"] = field.logContext
                }
            }
        }

        var dataPayloadLength: Int {
            switch self {
            case .adaptationField: 0
            case .dataPayload(let data): data.count
            case .both(_, let data): data.count
            }
        }

        var bytes: [UInt8] {
            switch self {
            case .adaptationField(let field): field.bytes
            case .dataPayload(let data): data
            case .both(let field, let data): field.bytes + data
            }
        }

        var adaptationFieldControl: TSHeader.AdaptationFieldControl {
            switch self {
            case .adaptationField: .adaptationFieldOnly
            case .dataPayload: .payloadOnly
            case .both: .adaptationFieldAndPayload
            }
        }

        var adaptationField: TSAdaptationField? {
            switch self {
            case .adaptationField(let field): return field
            case .dataPayload: return nil
            case .both(let field, _): return field
            }
        }

        var dataPayload: [UInt8] {
            switch self {
            case .adaptationField: return []
            case .dataPayload(let data): return data
            case .both(_, let data): return data
            }
        }

        fileprivate init(
            adaptationFieldControl control: TSHeader.AdaptationFieldControl,
            data: [UInt8]
        ) throws {
            switch control {
            case .adaptationFieldOnly:
                self = .adaptationField(try TSAdaptationField(bytes: data))
            case .payloadOnly:
                self = .dataPayload(data)
            case .adaptationFieldAndPayload:
                let field = try TSAdaptationField(bytes: data)
                self = .both(field, Array(data[Int(field.length + 1)...]))
            case .reserved:
                self = .dataPayload(data)
            }
        }
    }

    public struct AdaptationFieldConfiguration: Equatable, Sendable {
        public let pcr: TSClockReference?
        public let opcr: TSClockReference?
        public let allowRandomAccess: Bool

        public init(
            pcr: TSClockReference? = nil,
            opcr: TSClockReference? = nil,
            allowRandomAccess: Bool = false
        ) {
            self.pcr = pcr
            self.opcr = opcr
            self.allowRandomAccess = allowRandomAccess
        }
    }
}

extension Array where Element == TSPacket {
    public init(bytes: [UInt8]) throws {
        var packets: [TSPacket] = []
        var offset = 0
        while offset + 188 <= bytes.count {
            let packetBytes = [UInt8](bytes[offset..<offset + 188])
            let packet = try TSPacket(bytes: packetBytes)
            packets.append(packet)
            offset += 188
        }
        self = packets
    }

    public var bytes: [UInt8] {
        flatMap { $0.bytes }
    }
}

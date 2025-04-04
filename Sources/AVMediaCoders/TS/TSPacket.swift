struct TSPacket: Equatable {
    let packetSize = 188
    let headerSize = 4
    let payloadSize = 184
    let header: TSHeader
    let payload: Payload

    var bytes: [UInt8] { header.bytes + payload.bytes }

    init(
        pid: UInt16,
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
                ? .both(af, data)
                : .adaptationField(af)
        } else {
            payload = .dataPayload(data)
        }
        header = TSHeader(
            isStartOfPayload: isStartOfPayload,
            pid: pid,
            adaptationFieldControl: payload.adaptationFieldControl,
            continuityCounter: continuityCounter
        )
    }

    init(bytes: [UInt8]) throws {
        guard bytes.count >= packetSize else {
            throw AVMediaCodersError.bufferTooShort
        }
        header = try TSHeader(bytes: Array(bytes[0..<headerSize]))

        payload = try Payload(
            adaptationFieldControl: header.adaptationFieldControl,
            data: Array(bytes[headerSize..<packetSize])
        )
    }
}

extension TSPacket {
    enum Payload: Equatable {
        case adaptationField(TSAdaptationField)
        case dataPayload([UInt8])
        case both(TSAdaptationField, [UInt8])

        var bytes: [UInt8] {
            switch self {
            case .adaptationField(let field):
                return field.bytes
            case .dataPayload(let data):
                return data
            case .both(let field, let data):
                return field.bytes + data
            }
        }

        var adaptationFieldControl: TSHeader.AdaptationFieldControl {
            switch self {
            case .adaptationField: .adaptationFieldOnly
            case .dataPayload: .payloadOnly
            case .both: .adaptationFieldAndPayload
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

    struct AdaptationFieldConfiguration {
        let pcr: TSClockReference?
        let opcr: TSClockReference?
        let allowRandomAccess: Bool

        init(
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

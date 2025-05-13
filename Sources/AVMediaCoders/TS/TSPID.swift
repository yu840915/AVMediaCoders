public enum TSPID: Equatable, Hashable, Sendable {
  case programAssociationTable
  case conditionalAccesssTable
  case transportStreamDescriptionTable
  case controlInformationTable
  case reserved
  case dvbMetaData(type: UInt16)
  case dataStream(streamID: UInt16)  //PMT, PES, Data section etc.
  case nullPacket

  var value: UInt16 {
    switch self {
    case .programAssociationTable: 0x0000
    case .conditionalAccesssTable: 0x0001
    case .transportStreamDescriptionTable: 0x0002
    case .controlInformationTable: 0x0003
    case .reserved: 0x0004
    case .dvbMetaData(let type): 0x0010 + type
    case .dataStream(let streamID): 0x0020 + streamID
    case .nullPacket: 0x1FFF
    }
  }

  init(rawValue: UInt16) throws {
    switch rawValue {
    case 0x0000: self = .programAssociationTable
    case 0x0001: self = .conditionalAccesssTable
    case 0x0002: self = .transportStreamDescriptionTable
    case 0x0003: self = .controlInformationTable
    case 0x1FFF: self = .nullPacket
    case 0x0004...0x000F: self = .reserved
    case 0x0010...0x001F:
      self = .dvbMetaData(type: rawValue - 0x0010)
    case 0x0020...0x1FFE:
      self = .dataStream(streamID: rawValue - 0x0020)
    default:
      throw AVMediaCodersError.invalidTS(.unexpectedPID)
    }
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(value)
  }
}

extension TSPID: CustomStringConvertible {
  public var description: String {
    switch self {
    case .programAssociationTable: return "PAT"
    case .conditionalAccesssTable: return "CAT"
    case .transportStreamDescriptionTable: return "TSDT"
    case .controlInformationTable: return "CIT"
    case .reserved: return "Reserved"
    case .dvbMetaData(let type): return "DVB-MetaData(\(type))"
    case .dataStream(let streamID): return "DataStream(\(streamID))"
    case .nullPacket: return "NullPacket"
    }
  }
}

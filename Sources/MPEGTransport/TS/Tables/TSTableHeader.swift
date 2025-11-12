struct TSTableHeader: Equatable {
  let tableID: TableID
  var isPrivateSection: Bool {
    byteRepresentation.privateIndicator
  }
  var sectionLength: UInt16 {
    byteRepresentation.sectionLength
  }
  let byteRepresentation: ByteRepresentation
  var bytes: [UInt8] {
    byteRepresentation.bytes
  }

  init(tableID: TableID, sectionLength: UInt16) throws {
    guard sectionLength <= tableID.maximumSectionLength else {
      throw MPEGTransportError.invalidTS(.sectionLengthOutOfBounds)
    }
    self.tableID = tableID
    byteRepresentation = ByteRepresentation(
      tableID: tableID.value,
      sectionSyntaxIndicator: true,
      privateIndicator: tableID.isPrivateSection,
      sectionLength: sectionLength
    )
  }

  init(bytes: [UInt8]) throws {
    byteRepresentation = try ByteRepresentation(bytes: bytes)
    tableID = try TableID(value: byteRepresentation.tableID)
    guard
      tableID.isPrivateSection == byteRepresentation.privateIndicator,
      byteRepresentation.sectionLength <= tableID.maximumSectionLength
    else {
      throw MPEGTransportError.invalidTS(.invalidHeader)
    }
  }
}

extension TSTableHeader {
  enum TableID: Equatable {
    case programAssociationSection
    case conditionalAccessSection
    case TSProgramMapSection
    case TSDescriptionSection
    case ISO14496SceneDescriptionSection
    case ISO14496ObjectDescriptionSection
    case metadataSection
    case IPMPControlInformationSection
    case reserved
    case userPrivate(id: UInt8)

    var isPrivateSection: Bool {
      switch self {
      case .programAssociationSection,
        .conditionalAccessSection,
        .TSDescriptionSection,
        .TSProgramMapSection:
        false
      default: true
      }
    }

    var maximumSectionLength: UInt16 {
      return isPrivateSection ? 0x0FFD : 0x03FD
    }

    var value: UInt8 {
      switch self {
      case .programAssociationSection: return 0x00
      case .conditionalAccessSection: return 0x01
      case .TSProgramMapSection: return 0x02
      case .TSDescriptionSection: return 0x03
      case .ISO14496SceneDescriptionSection: return 0x04
      case .ISO14496ObjectDescriptionSection: return 0x05
      case .metadataSection: return 0x06
      case .IPMPControlInformationSection: return 0x07
      case .reserved: return 0x08
      case let .userPrivate(id): return 0x40 + id
      }
    }

    init(value: UInt8) throws {
      self =
        switch value {
        case 0x00: .programAssociationSection
        case 0x01: .conditionalAccessSection
        case 0x02: .TSProgramMapSection
        case 0x03: .TSDescriptionSection
        case 0x04: .ISO14496SceneDescriptionSection
        case 0x05: .ISO14496ObjectDescriptionSection
        case 0x06: .metadataSection
        case 0x07: .IPMPControlInformationSection
        case 0x08...0x3F: .reserved
        case 0x40...0xFE: .userPrivate(id: value - 0x40)
        default: throw MPEGTransportError.invalidTS(.invalidHeader)
        }
    }
  }

  struct ByteRepresentation: Equatable {
    let tableID: UInt8
    let sectionSyntaxIndicator: Bool
    let privateIndicator: Bool
    let sectionLength: UInt16

    var bytes: [UInt8] {
      let part2: UInt8 =
        (sectionSyntaxIndicator ? 0x80 : 0x00) | (privateIndicator ? 0x40 : 0x00)
        | (UInt8(sectionLength >> 8 & 0x00F))
      let part3: UInt8 = UInt8(sectionLength & 0x00FF)
      return [tableID, part2, part3]
    }

    init(
      tableID: UInt8,
      sectionSyntaxIndicator: Bool,
      privateIndicator: Bool,
      sectionLength: UInt16
    ) {
      self.tableID = tableID
      self.sectionSyntaxIndicator = sectionSyntaxIndicator
      self.privateIndicator = privateIndicator
      self.sectionLength = sectionLength
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 3 else {
        throw MPEGTransportError.bufferTooShort
      }
      tableID = bytes[0]
      sectionSyntaxIndicator = bytes[1] & 0x80 != 0
      privateIndicator = bytes[1] & 0x40 != 0
      sectionLength = UInt16(bytes[1] & 0x0F) << 8 | UInt16(bytes[2])
    }
  }
}

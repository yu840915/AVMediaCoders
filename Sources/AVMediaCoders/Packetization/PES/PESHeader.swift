import CoreMedia

struct PESHeader: Equatable {
  let type: StreamType
  var pesPacketLength: UInt16 {
    UInt16(byteFormat.pesPacketLength)
  }
  var payloadLength: Int {
    Int(pesPacketLength) - type.extensionBytes.count
  }
  let byteFormat: MainPartByteFormat
  let bytes: [UInt8]

  init(type: StreamType, payloadLength: UInt16) {
    self.type = type
    byteFormat = MainPartByteFormat(
      streamID: type.streamID,
      pesPacketLength: payloadLength + UInt16(type.extensionBytes.count)
    )
    bytes = byteFormat.bytes + type.extensionBytes
  }

  init(bytes: [UInt8]) throws {
    let byteFormat = try MainPartByteFormat(bytes: bytes)
    type = try .init(byteFormat: byteFormat, extensionBytes: Array(bytes.dropFirst(6)))
    self.byteFormat = byteFormat
    self.bytes = byteFormat.bytes + type.extensionBytes
  }

}

extension PESHeader {
  enum StreamType: Equatable {
    case privateStream1(extension: PESHeaderExtension)
    case paddingStream
    case privateStream2
    case audio(streamID: UInt8, extension: PESHeaderExtension)
    case video(streamID: UInt8, extension: PESHeaderExtension)

    var streamID: UInt8 {
      switch self {
      case .privateStream1: 0xBD
      case .paddingStream: 0xBE
      case .privateStream2: 0xBF
      case .audio(let streamID, _): 0xC0 + streamID
      case .video(let streamID, _): 0xE0 + streamID
      }
    }

    var extensionBytes: [UInt8] {
      switch self {
      case .privateStream1(let ext): ext.bytes
      case .audio(_, let ext): ext.bytes
      case .video(_, let ext): ext.bytes
      default: []
      }
    }

    var pts: CMTime? {
      return switch self {
      case .privateStream1(let ext),
        .audio(_, let ext),
        .video(_, let ext):
        ext.ptsAndDts.pts
      default: nil
      }
    }

    var dts: CMTime? {
      return switch self {
      case .privateStream1(let ext),
        .audio(_, let ext),
        .video(_, let ext):
        ext.ptsAndDts.dts
      default: nil
      }
    }

    init(videoStreamID: UInt8, extension: PESHeaderExtension) throws {
      guard videoStreamID <= 0x0F else {
        throw AVMediaCodersError.invalidPES(.invalidStreamID)
      }
      self = .video(streamID: videoStreamID, extension: `extension`)
    }

    init(audioStreamID: UInt8, extension: PESHeaderExtension) throws {
      guard audioStreamID <= 0x1F else {
        throw AVMediaCodersError.invalidPES(.invalidStreamID)
      }
      self = .audio(streamID: audioStreamID, extension: `extension`)
    }

    fileprivate init(
      byteFormat: MainPartByteFormat,
      extensionBytes bytes: [UInt8]
    ) throws {
      let streamID = byteFormat.streamID
      self =
        switch streamID {
        case 0xBD: .privateStream1(extension: try PESHeaderExtension(bytes: bytes))
        case 0xBE: .paddingStream
        case 0xBF: .privateStream2
        case 0xC0...0xDF:
          .audio(streamID: streamID - 0xC0, extension: try PESHeaderExtension(bytes: bytes))
        case 0xE0...0xEF:
          .video(streamID: streamID - 0xE0, extension: try PESHeaderExtension(bytes: bytes))
        default: throw AVMediaCodersError.invalidPES(.invalidStreamID)
        }
    }
  }
}

extension PESHeader {
  struct MainPartByteFormat: Equatable {
    let startCode: [UInt8] = [0x00, 0x00, 0x01]
    let streamID: UInt8
    let pesPacketLength: UInt16
    let bytes: [UInt8]

    init(streamID: UInt8, pesPacketLength: UInt16) {
      self.streamID = streamID
      self.pesPacketLength = pesPacketLength
      bytes = startCode + [streamID] + pesPacketLength.bigEndianBytes
    }

    init(bytes: [UInt8]) throws {
      guard bytes.count >= 6 else {
        throw AVMediaCodersError.bufferTooShort
      }
      guard bytes.starts(with: [0x00, 0x00, 0x01]) else {
        throw AVMediaCodersError.invalidPES(.invalidStartCode)
      }
      streamID = bytes[3]
      pesPacketLength = try UInt16(bigEndianBytes: Array(bytes[4...5]))
      self.bytes = Array(bytes.prefix(6))
    }
  }

}

import LogContext

//REF: https://dvd.sourceforge.net/dvdinfo/pes-hdr.html

public struct PESHeader: Equatable, Sendable, LogContextReadable {
  static let unboundedPacketLength = 0
  let type: StreamType
  var pesPacketLength: UInt16 {
    byteFormat.pesPacketLength
  }

  /// A `PES_packet_length` of 0 means the packet is unbounded: its payload runs
  /// to the end of the enclosing buffer, delimited by the next PES start code.
  ///
  /// ISO/IEC 13818-1 permits this only for video elementary streams, and it is
  /// the standard escape hatch for access units larger than the 16-bit length
  /// field can express (HEVC/H.264 IDR slices routinely exceed 64 KiB).
  var isUnbounded: Bool {
    pesPacketLength == 0
  }

  /// The declared payload length, or `nil` when the packet is unbounded and the
  /// caller should consume the remainder of the buffer instead.
  var payloadLength: Int? {
    guard !isUnbounded else { return nil }
    return Int(pesPacketLength) - type.extensionBytes.count
  }
  let byteFormat: MainPartByteFormat
  let bytes: [UInt8]
  public var logContext: LogContext {
    LogContext {
      $0["type"] = type.logContext
      $0["Length"] = pesPacketLength
      $0["payloadLength"] = payloadLength.map { $0.formattedSize } ?? "unbounded"
    }
  }

  init(type: StreamType, payloadLength: Int) {
    self.type = type
    let packetLength = payloadLength + type.extensionBytes.count
    byteFormat = MainPartByteFormat(
      streamID: type.streamID,
      pesPacketLength: packetLength > Int(UInt16.max) ? 0 : UInt16(packetLength)
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
  public enum StreamType: Equatable, Sendable {
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

    var pts: MediaTimestamp? {
      return switch self {
      case .privateStream1(let ext),
        .audio(_, let ext),
        .video(_, let ext):
        ext.ptsAndDts.pts
      default: nil
      }
    }

    var dts: MediaTimestamp? {
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
        throw MPEGTransportError.invalidPES(.invalidStreamID)
      }
      self = .video(streamID: videoStreamID, extension: `extension`)
    }

    init(audioStreamID: UInt8, extension: PESHeaderExtension) throws {
      guard audioStreamID <= 0x1F else {
        throw MPEGTransportError.invalidPES(.invalidStreamID)
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
        default: throw MPEGTransportError.invalidPES(.invalidStreamID)
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
        throw MPEGTransportError.bufferTooShort
      }
      guard bytes.starts(with: [0x00, 0x00, 0x01]) else {
        throw MPEGTransportError.invalidPES(.invalidStartCode)
      }
      streamID = bytes[3]
      pesPacketLength = try UInt16(bigEndianBytes: Array(bytes[4...5]))
      self.bytes = Array(bytes.prefix(6))
    }
  }

}

extension PESHeader.StreamType: LogContextReadable {
  public var logContext: LogContext {
    LogContext {
      switch self {
      case .privateStream1:
        $0["type"] = "Private Stream 1"
      case .paddingStream:
        $0["type"] = "Padding Stream"
      case .privateStream2:
        $0["type"] = "Private Stream 2"
      case .audio(let streamID, let ext):
        $0["type"] = "Audio Stream"
        $0["streamID"] = streamID
        $0["ext"] = ext.logContext
      case .video(let streamID, let ext):
        $0["type"] = "Video Stream"
        $0["streamID"] = streamID
        $0["ext"] = ext.logContext
      }
    }
  }
}

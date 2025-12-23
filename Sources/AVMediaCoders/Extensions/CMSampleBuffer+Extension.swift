import CoreMedia
import LogContext

extension CMSampleBuffer {
  var containsKeyFrame: Bool {
    guard
      let attachments =
        CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: false)
        as? [[CFString: Any]]
    else {
      return false
    }

    for attachment in attachments {
      if let dependsOnOthers = attachment[kCMSampleAttachmentKey_DependsOnOthers] as? Bool,
        !dependsOnOthers
      {
        return true
      }
    }
    return false
  }

  func configureAttachments(_ configure: (inout CFMutableDictionary) -> Void) {
    guard
      let attachments =
        CMSampleBufferGetSampleAttachmentsArray(self, createIfNecessary: true)
    else {
      return
    }
    var dict = unsafeBitCast(
      CFArrayGetValueAtIndex(attachments, 0),
      to: CFMutableDictionary.self,
    )
    configure(&dict)
  }
}

struct ParameterSetInfo {
  let data: Data
  let headerLength: Int32
}

struct CompressedDataInfo {
  let data: Data
  let isKeyFrame: Bool
}

extension CMSampleBuffer: @retroactive LogContextReading {
  public var logContext: LogContext {
    LogContext {
      $0["format"] = self.formatDescription?.logContext
      $0["valid"] = self.isValid
      $0["samples"] = self.numSamples
      $0["size"] = self.totalSampleSize
      $0["pts"] = self.presentationTimeStamp
      $0["dts"] = self.decodeTimeStamp
      $0["ptsOutput"] = self.outputPresentationTimeStamp
      $0["dtsOutput"] = self.outputPresentationTimeStamp
      $0["ready"] = self.dataReadiness
      $0["hasKeyframe"] = self.containsKeyFrame
    }
  }
}

extension CMSampleBuffer.DataReadiness: @retroactive CustomStringConvertible {
  public var description: String {
    switch self {
    case .ready: "ready"
    case .notReady: "notReady"
    case let .failed(status): "failed(\(status))"
    @unknown default:
      fatalError()
    }
  }
}

extension CMTime: @retroactive CustomStringConvertible {
  public var description: String {
    "\(value)/\(timescale)"
  }
}

extension CMFormatDescription: @retroactive LogContextReading {
  public var logContext: LogContext {
    LogContext {
      $0["len"] = self.nalUnitHeaderLength
      $0["IDs"] = self.identifiers
      $0["type"] = self.mediaType
      $0["subtype"] = self.mediaSubType
      $0["tags"] = self.tagCollections
      $0["frames"] = self.frameQuanta
      $0["audioFmt"] = self.audioFormatList
    }
  }
}

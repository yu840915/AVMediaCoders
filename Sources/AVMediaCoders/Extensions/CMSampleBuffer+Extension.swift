import AVFoundation

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

}

struct ParameterSetInfo {
  let data: Data
  let headerLength: Int32
}

struct CompressedDataInfo {
  let data: Data
  let isKeyFrame: Bool
}

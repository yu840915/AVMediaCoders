/// Time Code SEI message (payload type 136)
public struct HEVCTimeCodeSEI: Sendable, Equatable {
  public let hours: UInt8
  public let minutes: UInt8
  public let seconds: UInt8
  public let frames: UInt8
  public let dropFrame: Bool

  public init(hours: UInt8, minutes: UInt8, seconds: UInt8, frames: UInt8, dropFrame: Bool = false)
  {
    self.hours = hours
    self.minutes = minutes
    self.seconds = seconds
    self.frames = frames
    self.dropFrame = dropFrame
  }

  /// Serialize to SEI message (simplified encoding)
  public func toSEIMessage() -> HEVCSEIMessage {
    var payload: [UInt8] = []
    // num_clock_ts = 1
    payload.append(0x01)
    // clock_timestamp_flag + units_field_based_flag + counting_type + full_timestamp_flag
    // + discontinuity_flag + cnt_dropped_flag + n_frames
    var flags: UInt8 = 0x80  // clock_timestamp_flag = 1
    if dropFrame { flags |= 0x04 }  // cnt_dropped_flag
    payload.append(flags)
    payload.append(frames)
    payload.append(seconds)
    payload.append(minutes)
    payload.append(hours)
    return HEVCSEIMessage(payloadType: .timeCode, payload: payload)
  }
}

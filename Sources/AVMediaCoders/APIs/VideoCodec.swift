import LogContext

public enum VideoCodec: LogContextValue {
  case avc
  case hevc

  public var description: String {
    switch self {
    case .avc: "AVC"
    case .hevc: "HEVC"
    }
  }
}

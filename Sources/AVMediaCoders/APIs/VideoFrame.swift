import CoreMedia
import RemoteCameraCore

public struct VideoFrame {
  public let buffer: CMSampleBuffer
  public let imageOrientation: ImageOrientation?
  public let inputDeviceDirection: DeviceDirection?

  public init(
    buffer: CMSampleBuffer,
    imageOrientation: ImageOrientation? = nil,
    inputDeviceDirection: DeviceDirection? = nil
  ) {
    self.buffer = buffer
    self.imageOrientation = imageOrientation
    self.inputDeviceDirection = inputDeviceDirection
  }
}

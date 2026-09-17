import MPEGTransport
import RemoteCameraCore
import Testing

@testable import AVMediaCoders

struct InternalSEIMessageTests {

  @Test
  func createSEINALUwithDeviceMotion() async throws {
    let sut = HEVCNALUnit.withDeviceMotion(
      deviceDirection: DeviceDirection(heading: 1.5, pitch: 0.1),
      imageOrientation: .bottom
    )

    #expect(sut != nil)
    #expect(sut?.internalSEIMessages.count == 2)
  }

  @Test
  func canAccessOrientationsThroughUtilGetters() async throws {
    let sut = HEVCNALUnit.withDeviceMotion(
      deviceDirection: DeviceDirection(heading: 1.5, pitch: 0.1),
      imageOrientation: .bottom
    )

    #expect(sut?.deviceDirection != nil)
    #expect(sut?.imageOrientation == .bottom)
  }
}

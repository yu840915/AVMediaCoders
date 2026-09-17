import Foundation
import MPEGTransport
import RemoteCameraCore

private let kInternalSEIID = UUID(uuidString: "5AA4A081-D5E3-4F31-8760-F22800515B37")!

extension HEVCNALUnit {
  static func withDeviceMotion(
    deviceDirection: DeviceDirection?,
    imageOrientation: ImageOrientation?
  ) -> HEVCNALUnit? {
    var messages: [HEVCSEIMessage] = []
    if let deviceDirection {
      messages.append(
        HEVCUserDataUnregisteredSEI(
          uuid: kInternalSEIID,
          userData: [InternalSEIMessageType.deviceDirection.rawValue]
            + DeviceOrientationMessage(deviceDirection).bytes
        ).toSEIMessage()
      )
    }
    if let imageOrientation {
      messages.append(
        HEVCUserDataUnregisteredSEI(
          uuid: kInternalSEIID,
          userData: [InternalSEIMessageType.imageOrientation.rawValue] + [imageOrientation.rawValue]
        ).toSEIMessage()
      )
    }
    if messages.isEmpty {
      return nil
    }
    return HEVCNALUnit.withSEIMessages(messages, isPrefix: true)
  }

  var internalSEIMessages: [HEVCUserDataUnregisteredSEI] {
    seiMessages.compactMap { sei in
      guard
        case .userDataUnregistered = sei.payloadType,
        let userSEI = HEVCUserDataUnregisteredSEI(payload: sei.payload),
        userSEI.uuid == kInternalSEIID
      else {
        return nil
      }
      return userSEI
    }
  }

  var deviceDirection: DeviceDirection? {
    for sei in internalSEIMessages {
      guard
        let typeVal = sei.userData.first,
        case .deviceDirection = InternalSEIMessageType(rawValue: typeVal),
        let msg = try? DeviceOrientationMessage(bytes: [UInt8](sei.userData.dropFirst()))
      else {
        continue
      }
      return msg.direction
    }
    return nil
  }

  var imageOrientation: ImageOrientation? {
    for sei in internalSEIMessages {
      guard
        let typeVal = sei.userData.first,
        case .imageOrientation = InternalSEIMessageType(rawValue: typeVal),
        let orientationVal = sei.userData.dropFirst().first,
        let orientation = ImageOrientation(rawValue: orientationVal)
      else {
        continue
      }
      return orientation
    }
    return nil
  }
}

enum InternalSEIMessageType: UInt8, Sendable {
  case deviceDirection = 1
  case imageOrientation = 2
}

struct DeviceOrientationMessage: Sendable {
  let heading: UInt16
  let pitch: UInt16
  var bytes: [UInt8] {
    heading.bigEndianBytes + pitch.bigEndianBytes
  }

  var direction: DeviceDirection {
    let heading = Double(heading) / 65535 * 2 * .pi
    let pitch = Double(pitch) / 65535 * .pi - .pi / 2
    return DeviceDirection(heading: heading, pitch: pitch)
  }

  init(bytes: [UInt8]) throws {
    guard bytes.count >= 4 else {
      throw MPEGTransportError.bufferTooShort
    }
    self.heading = try UInt16(bigEndianBytes: Array(bytes[0..<2]))
    self.pitch = try UInt16(bigEndianBytes: Array(bytes[2..<4]))
  }

  init(_ direction: DeviceDirection) {
    self.heading = UInt16(direction.heading / (2 * .pi) * 65535)
    self.pitch = UInt16((direction.pitch + .pi / 2) / .pi * 65535)
  }
}

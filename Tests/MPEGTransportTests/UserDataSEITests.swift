import Foundation
import MPEGTransport
import Testing

let uuid = UUID(uuidString: "12345678-1234-5678-1234-567812345678")!

struct UserDataSEITests {

  @Test func equality() async throws {
    let sut = [
      HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [42]).toSEIMessage(),
      HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [UInt8]("Hello".data(using: .utf8)!))
        .toSEIMessage(),
    ]

    #expect(
      sut == [
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [42]).toSEIMessage(),
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [UInt8]("Hello".data(using: .utf8)!))
          .toSEIMessage(),
      ],
    )
  }

  @Test
  func packageSEIMessages() async throws {

    let bytes = HEVCNALUnit.withSEIMessages(
      [
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [42]).toSEIMessage(),
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [UInt8]("Hello".data(using: .utf8)!))
          .toSEIMessage(),
      ],
    ).bytes

    let sut = try HEVCNALUnit(bytes: bytes)

    #expect(
      sut.seiMessages == [
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [42]).toSEIMessage(),
        HEVCUserDataUnregisteredSEI(uuid: uuid, userData: [UInt8]("Hello".data(using: .utf8)!))
          .toSEIMessage(),
      ],
    )
  }
}

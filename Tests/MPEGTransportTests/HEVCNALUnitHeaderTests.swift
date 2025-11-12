import Testing

@testable import MPEGTransport

struct HEVCNALUnitHeaderTests {
  @Test
  func decodeValidSps() async throws {
    let headerData: [UInt8] = [0x42, 0x01]
    let sut = try HEVCNALUnitHeader(bytes: headerData)

    #expect(sut.type == .sps)
    #expect(sut.layerID == 0)
    #expect(sut.temporalIDPlus1 == 1)
  }

  @Test
  func encodeSps() async throws {
    let sut = HEVCNALUnitHeader(type: .sps, layerID: 0, temporalIDPlus1: 1)
    let bytes = sut.bytes

    #expect(bytes == [0x42, 0x01])
  }

  @Test
  func encodeAndDecode() async throws {
    let sut = HEVCNALUnitHeader(type: .vps, layerID: 0b101111, temporalIDPlus1: 0b101)
    let bytes = sut.bytes
    let decoded = try HEVCNALUnitHeader(bytes: bytes)

    #expect(sut == decoded)
  }

  @Test
  func rejectNon0ForbiddenBit() async throws {
    #expect(throws: MPEGTransportError.invalidHEVC(.nonZeroForbiddenBit), nil) {
      try HEVCNALUnitHeader(bytes: [0b11000010, 0b10100000])
    }
  }

  @Test
  func rejectInvalidNALUnitTypeValue() async throws {
    #expect(throws: MPEGTransportError.invalidHEVC(.invalidNALUnitType), nil) {
      try HEVCNALUnitHeader(bytes: [0b01111110, 0b10100000])
    }
  }

}

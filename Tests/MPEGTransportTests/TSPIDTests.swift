import Testing

@testable import MPEGTransport

struct TSPIDTests {
  @Test(
    arguments: [(UInt16, TSPID)](
      [
        (0, .programAssociationTable),
        (1, .conditionalAccesssTable),
        (2, .transportStreamDescriptionTable),
        (3, .controlInformationTable),
        (0x1FFF, .nullPacket),
      ]
    )
  )
  func simpleMapping(_ value: UInt16, _ pid: TSPID) async throws {
    #expect(try TSPID(rawValue: value) == pid)
    #expect(pid.value == value)
  }

  @Test(arguments: 0x04...0x0F)
  func reserved(_ value: UInt16) async throws {
    #expect(try TSPID(rawValue: value) == .reserved)
  }

  @Test(arguments: 0x10...0x1F)
  func dvbMetaData(_ value: UInt16) async throws {
    #expect(try TSPID(rawValue: value) == .dvbMetaData(type: value - 0x10))
    #expect(TSPID.dvbMetaData(type: value - 0x10).value == value)
  }

  @Test(arguments: [0x0020, 0xFFA, 0xFFC, 0x1FFE])
  func dataStream(_ value: Int) async throws {
    let rawVal = UInt16(value)
    #expect(try TSPID(rawValue: rawVal) == .dataStream(streamID: rawVal - 0x20))
    #expect(TSPID.dataStream(streamID: rawVal - 0x20).value == rawVal)
  }

  @Test
  func rejectPIDGreaterThanNullPacked() async throws {
    #expect(throws: MPEGTransportError.invalidTS(.unexpectedPID)) {
      try TSPID(rawValue: 0x2000)
    }
  }
}

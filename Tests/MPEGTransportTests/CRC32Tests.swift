import Testing

@testable import MPEGTransport

struct CRC32Tests {
  @Test(
    arguments: [([UInt8], UInt32)]([
      (
        [
          0x00, 0xB0, 0x0D, 0x12,
          0x34, 0xC1, 0x00, 0x00,
          0x00, 0x01, 0xE1, 0x00,
          0x00, 0x02, 0xE2, 0x00,
        ],
        UInt32(0x820E_1AE9)
      ),
      (
        [
          0x31, 0x32, 0x33, 0x34,
          0x35, 0x36, 0x37, 0x38,
          0x39,
        ],
        UInt32(0x0376_E6E7)
      ),
    ]))
  func calculate(_ bytes: [UInt8], _ crc: UInt32) async throws {
    #expect(CRC32.calculate(bytes) == crc)
  }
}

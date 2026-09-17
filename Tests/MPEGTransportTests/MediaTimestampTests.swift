import MPEGTransport
import Testing

struct MediaTimestampTest {
  @Test func addition() async throws {
    let timestamp1 = MediaTimestamp(value: 1000, scale: .video)
    let timestamp2 = MediaTimestamp(value: 2000, scale: .video)

    let sut = timestamp1 + timestamp2

    #expect(sut == MediaTimestamp(value: 3000, scale: .video))
  }

  @Test func subtraction() async throws {
    let timestamp1 = MediaTimestamp(value: 3000, scale: .video)
    let timestamp2 = MediaTimestamp(value: 2000, scale: .video)

    let sut = timestamp1 - timestamp2

    #expect(sut == MediaTimestamp(value: 1000, scale: .video))
  }
}

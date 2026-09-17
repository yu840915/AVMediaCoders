import MPEGTransport
import Testing

struct RelativeMediaTimestampConverterTests {

  @Test
  func convertFirstTimestampToZero() async throws {
    var sut = RelativeMediaTimestampConverter()
    let firstTimestamp = MediaTimestamp(value: 3000, scale: .video)

    let result = sut.convert(firstTimestamp)

    #expect(result == MediaTimestamp(value: 0, scale: .video))
  }

  @Test
  func convertToRelTimestampWithRespectToFirstTimestamp() async throws {
    var sut = RelativeMediaTimestampConverter()
    let firstTimestamp = MediaTimestamp(value: 3000, scale: .video)
    let secondTimestamp = MediaTimestamp(value: 3100, scale: .video)

    _ = sut.convert(firstTimestamp)
    let result = sut.convert(secondTimestamp)

    #expect(result == MediaTimestamp(value: 100, scale: .video))
  }

  @Test
  func convertFirstTimestampToLocalTimestamp() async throws {
    var sut = RelativeMediaTimestampConverter(
      strategy: .alignWithLocalClock {
        MediaTimestamp(value: 100, scale: .video)
      },
    )
    let firstTimestamp = MediaTimestamp(value: 3000, scale: .video)

    let result = sut.convert(firstTimestamp)

    #expect(result == MediaTimestamp(value: 100, scale: .video))
  }

  @Test
  func convertToRelTimestampWithRespectToLocalTimestamp() async throws {
    var sut = RelativeMediaTimestampConverter(
      strategy: .alignWithLocalClock {
        MediaTimestamp(value: 100, scale: .video)
      },
    )
    let firstTimestamp = MediaTimestamp(value: 3000, scale: .video)
    let secondTimestamp = MediaTimestamp(value: 3100, scale: .video)

    _ = sut.convert(firstTimestamp)
    let result = sut.convert(secondTimestamp)

    #expect(result == MediaTimestamp(value: 200, scale: .video))
  }
}

# MediaCoders

Swift packages for encoding and decoding video and sending it over MPEG transport streams on Apple platforms.

- **MPEGTransport**: works with MPEG-2 transport streams (TS). It handles PES packets, PAT/PMT tables, TS packet splitting and reassembly, a muxer and demuxer, HEVC NAL unit headers, SEI messages and media timestamps.
- **AVMediaCoders**: VideoToolbox-based H.264 (AVC) / HEVC compression and decompression, plus conversion between `CMSampleBuffer` video frames and PES packets.

## Requirements

- Swift 6.1+
- iOS 17+ / macOS 15+

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/yu840915/AVMediaCoders.git", branch: "main"),
],
targets: [
    .target(
        name: "MyTarget",
        dependencies: [
            .product(name: "AVMediaCoders", package: "AVMediaCoders"),
            .product(name: "MPEGTransport", package: "AVMediaCoders"),
        ]
    ),
]
```

## Usage

### Encode frames into PES packets

`createVideoPacketier` compresses each `VideoFrame` with VideoToolbox and publishes the resulting PES packets.

```swift
import AVMediaCoders
import Combine

let configuration = VideoCompressionConfiguration(
    width: 1920,
    height: 1080,
    codec: .hevc,
    bitrate: 6_000_000,
    frameRate: 30,
    maxKeyFrameInterval: 60
)
let packetizer = try createVideoPacketier(streamID: 0, configuration: configuration)

packetizer.onOutputPES
    .sink { pesPacket in
        // Send pesPacket.bytes, e.g. through an AVProgramWriter
    }
    .store(in: &bag)

packetizer.packetize(VideoFrame(buffer: sampleBuffer))
```

### Decode PES packets into frames

```swift
let depacketizer = createVideoDepacketizer(streamID: 0)

depacketizer.onOutputSampleBuffer
    .sink { frame in
        // frame.buffer is a decoded CMSampleBuffer
    }
    .store(in: &bag)

depacketizer.depacketize(pesPacket)
```

You can also use the individual stages yourself: `VideoCompressor`, `VideoPacketizer`, `VideoDepacketizer` and `VideoDecompressor`.

### Mux an audio/video program

```swift
import MPEGTransport

final class Output: TSMuxerOutputDelegate {
    func muxer(_ muxer: TSMuxer, didOutputPackets packets: [TSPacket]) {
        // Write packets.flatMap(\.bytes) to the network or a file
    }
}

let output = Output()
let muxer = await TSMuxer(outputDelegate: output)
let writer = try await muxer.buildAVProgram(
    programInfo: [],
    videoType: .hevc,
    audioType: .aac
)
try await writer.sendVideoPackets([pesPacket])
```

### Demux an audio/video program

```swift
let delegate = await AVProgramDemuxerOutputDelegate()
delegate.onNewProgram
    .sink { reader in
        reader.onVideoPacket
            .sink { output in
                depacketizer.depacketize(output.packet)
            }
            .store(in: &bag)
    }
    .store(in: &bag)

let demuxer = TSDemuxer(outputDelegate: delegate)
await demuxer.feed(try TSPacket(bytes: packetBytes))
```

## Debug logging

Logs go to `OSLog` under the subsystems `com.teleshot.MPEGTransport` and `com.teleshot.AVMediaCoders`. You can turn on more detailed I/O logging with package traits:

| Trait | Logs |
| --- | --- |
| `DEBUG_PACKETIZATION_IO` | TS/PES packetization, muxing and demuxing |
| `DEBUG_MEDIA_DATA_IO` | Compressed media data |

```bash
swift build --traits DEBUG_PACKETIZATION_IO,DEBUG_MEDIA_DATA_IO
```

A package that depends on this one can turn them on with `.package(url: ..., branch: "main", traits: ["DEBUG_PACKETIZATION_IO"])`.

## Testing

```bash
swift test
```

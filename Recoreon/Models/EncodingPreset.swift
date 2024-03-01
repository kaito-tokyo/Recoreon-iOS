enum EncodingAudioChannelMapping {
  case screenMicToScreenMic
  case screenMicToScreen
  case screenMicToMic
  case screenToScreenMic
  case screenToScreen
  case screenToMic
}

struct EncodingPreset: Hashable {
  let name: String
  let videoCodec: String
  let videoBitrate: String
  let audioCodec: String
  let audioBitrate: String
  let framerate: String
  let filter: [EncodingAudioChannelMapping: [String]]
  let estimatedDurationFactor: Double

  static let lowQuality = EncodingPreset(
    name: "LowQuality",
    videoCodec: "h264_videotoolbox",
    videoBitrate: "1000k",
    audioCodec: "aac_at",
    audioBitrate: "64k", framerate: "60",
    filter: [
      .screenMicToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenMicToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenMicToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
      .screenToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
    ],
    estimatedDurationFactor: 0.25)

  static let twoTimeSpeedLowQuality = EncodingPreset(
    name: "twoTimeSpeedLowQuality",
    videoCodec: "h264_videotoolbox",
    videoBitrate: "1000k",
    audioCodec: "aac_at",
    audioBitrate: "64k", framerate: "60",
    filter: [
      .screenMicToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenMicToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenMicToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
      .screenToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
    ],
    estimatedDurationFactor: 0.25)

  static let fourTimeSpeedLowQuality = EncodingPreset(
    name: "fourTimeSpeedLowQuality",
    videoCodec: "h264_videotoolbox",
    videoBitrate: "1000k",
    audioCodec: "aac_at",
    audioBitrate: "64k", framerate: "60",
    filter: [
      .screenMicToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenMicToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenMicToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:2] aresample=async=1:first_pts=0 [r0]; [r0] atempo=4 [a1]",
        ],
      .screenToScreenMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
      .screenToScreen:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
        ],
      .screenToMic:
        [
          "-filter_complex",
          "[0:0] setpts=PTS/4 [v0]",
          "-filter_complex",
          "[0:1] atempo=4 [a0]",
          "-filter_complex",
          "[1:0] acopy [a1]",
        ],
    ],
    estimatedDurationFactor: 0.25)

  static let allPresets: [EncodingPreset] = [
    .lowQuality,
    .twoTimeSpeedLowQuality,
    .fourTimeSpeedLowQuality,
  ]
}

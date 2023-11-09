enum EncodingAudioChannelMapping {
  case screenMicToScreenMic
  case screenMicToScreen
  case screenMicToMic
  case screenToScreenMic
  case screenToScreen
  case screenToMic
}

struct EncodingPreset {
  let name: String
  let videoCodec: String
  let videoBitrate: String
  let audioCodec: String
  let audioBitrate: String
  let framerate: String
  let filter: [EncodingAudioChannelMapping: [String]]
  let estimatedDurationFactor: Double
}

let kRecoreonLowBitrateFourTimes = EncodingPreset(
  name: "LowBitrateFourTimes",
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

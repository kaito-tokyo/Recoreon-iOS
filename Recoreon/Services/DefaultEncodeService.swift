import Foundation
import RecoreonCommon
import ffmpegkit

struct DefaultEncodeService: EncodeService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService

  init(fileManager: FileManager, recoreonPathService: RecoreonPathService) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
  }

  func generateEncodedVideoURL(
    screenRecordEntry: ScreenRecordEntry,
    preset: EncodingPreset
  ) -> URL {
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    return recoreonPathService.generateEncodedVideoURL(recordID: recordID, presetName: preset.name)
  }

  func removeEncodedVideo(encodedVideoEntry: EncodedVideoEntry) {
    try? fileManager.removeItem(at: encodedVideoEntry.url)
  }

  func encode(
    screenRecordEntry: ScreenRecordEntry, preset: EncodingPreset,
    progressHandler: @escaping (Double, Double) -> Void
  ) async -> EncodedVideoEntry? {
    let durations = getDurationOfStreams(screenRecordEntry.url)
    let audioChannelMapping = getAudioChannelMapping(durations: durations)
    guard let filter = preset.filter[audioChannelMapping] else { return nil }
    let recordID = recoreonPathService.getRecordID(screenRecordURL: screenRecordEntry.url)
    let encodedVideoURL = recoreonPathService.generateEncodedVideoURL(
      recordID: recordID, presetName: preset.name)
    var arguments = [
      "-y",
      "-i",
      screenRecordEntry.url.path(),
      "-f",
      "lavfi",
      "-i",
      "anullsrc=channel_layout=stereo:sample_rate=48000",
      "-c:v",
      preset.videoCodec,
      "-vb",
      preset.videoBitrate,
      "-c:a",
      preset.audioCodec,
      "-ab",
      preset.audioBitrate,
      "-r",
      preset.framerate,
      "-shortest",
    ]
    arguments += filter
    arguments += getMappingOptions(audioChannelMapping: audioChannelMapping)
    arguments.append(encodedVideoURL.path())

    let duration = getDuration(screenRecordEntry.url) * 1000

    return await withCheckedContinuation { continuation in
      FFmpegKit.execute(
        withArgumentsAsync: arguments,
        withCompleteCallback: { session in
          guard let ret = session?.getReturnCode() else {
            continuation.resume(returning: .none)
            return
          }
          if ReturnCode.isSuccess(ret) {
            let encodedVideoEntry = EncodedVideoEntry(url: encodedVideoURL, preset: preset)
            continuation.resume(returning: encodedVideoEntry)
          } else {
            continuation.resume(returning: nil)
          }
        }, withLogCallback: nil,
        withStatisticsCallback: { statistic in
          guard let time = statistic?.getTime() else { return }
          progressHandler(time, duration * preset.estimatedDurationFactor)
        })
    }
  }

  private func getDuration(_ url: URL) -> Double {
    let session = FFprobeKit.getMediaInformation(url.path())
    guard let info = session?.getMediaInformation(),
      let durationString = info.getDuration(),
      let duration = Double(durationString)
    else { return Double.nan }
    return duration
  }

  private func getDurationOfStreams(_ url: URL) -> [Double] {
    let session = FFprobeKit.getMediaInformation(url.path())
    guard let info = session?.getMediaInformation(),
      let streams = info.getStreams() as? [StreamInformation]
    else { return [] }
    return streams.map { info -> Double in
      guard let properties = info.getAllProperties(),
        let tags = properties["tags"] as? NSDictionary,
        let durationString = tags["DURATION"] as? String
      else { return 0.0 }
      let components = durationString.components(separatedBy: ":")
      guard
        let hours = Double(components[0]),
        let minutes = Double(components[1]),
        let seconds = Double(components[2])
      else { return Double.nan }
      return hours * 3600.0 + minutes * 60.0 + seconds
    }
  }

  private func getAudioChannelMapping(durations: [Double]) -> EncodingAudioChannelMapping {
    if durations[2] > 0.0 {
      return .screenMicToScreenMic
    } else {
      return .screenToScreenMic
    }
  }

  private func getMappingOptions(audioChannelMapping: EncodingAudioChannelMapping) -> [String] {
    switch audioChannelMapping {
    case .screenMicToScreenMic, .screenToScreenMic:
      return ["-map", "[v0]", "-map", "[a0]", "-map", "[a1]"]
    default:
      return []
    }
  }
}

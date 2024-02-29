import Foundation

import UIKit

private let paths = RecoreonPaths()
private let fileManager = FileManager.default

class ScreenRecordService {
  private let thumbnailExtractor = ThumbnailExtractor()

  private func cropCGImage(_ cgImage: CGImage) -> CGImage? {
    let width = cgImage.width
    let height = cgImage.height
    if width > height {
      let origin = CGPoint(x: (width - height) / 2, y: 0)
      let size = CGSize(width: height, height: height)
      return cgImage.cropping(to: CGRect(origin: origin, size: size))
    } else {
      let origin = CGPoint(x: 0, y: (height - width) / 2)
      let size = CGSize(width: width, height: width)
      return cgImage.cropping(to: CGRect(origin: origin, size: size))
    }
  }

  func listScreenRecordEntries() -> [ScreenRecordEntry] {
    paths.ensureAppGroupDirectoriesExists()
    paths.ensureSandboxDirectoriesExists()

    return paths.listRecordURLs().map { url in
      let attrs = try? fileManager.attributesOfItem(atPath: url.path())
      return ScreenRecordEntry(
        url: url,
        encodedVideoCollection: getEncodedVideoCollection(url),
        size: attrs?[.size] as? UInt64 ?? 0,
        creationDate: attrs?[.creationDate] as? Date ?? Date(timeIntervalSince1970: 0)
      )
    }
  }

  func getThumbnailImage(_ screenRecordURL: URL) -> UIImage? {
    let thumbnailURL = paths.getThumbnailURL(screenRecordURL)
    return UIImage(contentsOfFile: thumbnailURL.path())
  }

  func generateThumbnail(_ screenRecordURL: URL) async {
    let thumbnailURL = paths.getThumbnailURL(screenRecordURL)
    let arguments = [
      "-y",
      "-i",
      screenRecordURL.path(),
      "-vf",
      "thumbnail",
      "-frames:v",
      "1",
      thumbnailURL.path(),
    ]
    return await withCheckedContinuation { continuation in
      FFmpegKit.execute(
        withArgumentsAsync: arguments,
        withCompleteCallback: { _ in
          continuation.resume()
        }
      )
    }
  }

  func listScreenRecordURLs() -> [URL] {
    paths.ensureAppGroupDirectoriesExists()
    paths.ensureSandboxDirectoriesExists()
    return paths.listRecordURLs()
  }

  func publishRecordedVideo(_ screenRecordURL: URL) -> Bool {
    paths.ensureAppGroupDirectoriesExists()
    paths.ensureSandboxDirectoriesExists()

    let sharedScreenRecordURL = paths.getSharedScreenRecordURL(screenRecordURL)
    do {
      try fileManager.copyItem(at: screenRecordURL, to: sharedScreenRecordURL)
      return true
    } catch {
      return false
    }
  }

  func encode(
    preset: EncodingPreset, screenRecordURL: URL,
    progressHandler: @escaping (Double, Double) -> Void
  ) async -> URL? {
    let durations = getDurationOfStreams(screenRecordURL)
    let audioChannelMapping = getAudioChannelMapping(durations: durations)
    guard let filter = preset.filter[audioChannelMapping] else { return nil }
    let encodedVideoURL = paths.getEncodedVideoURL(screenRecordURL, suffix: "-\(preset.name)")
    var arguments = [
      "-y",
      "-i",
      screenRecordURL.path(),
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

    let duration = getDuration(screenRecordURL) * 1000

    return await withCheckedContinuation { continuation in
      FFmpegKit.execute(
        withArgumentsAsync: arguments,
        withCompleteCallback: { session in
          guard let ret = session?.getReturnCode() else {
            continuation.resume(returning: nil)
            return
          }
          if ReturnCode.isSuccess(ret) {
            continuation.resume(returning: encodedVideoURL)
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

  func remux(_ screenRecordURL: URL) async -> URL? {
    let previewVideoURL = paths.getPreviewVideoURL(screenRecordURL)
    let arguments = [
      "-i",
      screenRecordURL.path(),
      "-c:v",
      "copy",
      "-c:a",
      "copy",
      previewVideoURL.path(),
    ]
    if fileManager.fileExists(atPath: previewVideoURL.path()) {
      return previewVideoURL
    }
    return await withCheckedContinuation { continuation in
      FFmpegKit.execute(
        withArgumentsAsync: arguments,
        withCompleteCallback: { session in
          let ret = session?.getReturnCode()
          if ReturnCode.isSuccess(ret) {
            continuation.resume(returning: previewVideoURL)
          } else {
            continuation.resume(returning: nil)
          }
        })
    }
  }

  func generateEncodedVideoURL(screenRecordURL: URL, encodingPreset: EncodingPreset) -> URL {
    let suffix = "-\(encodingPreset.name)"
    return paths.getEncodedVideoURL(screenRecordURL, suffix: suffix)
  }

  func getEncodedVideoURL(screenRecordURL: URL, encodingPreset: EncodingPreset) -> URL? {
    let encodedVideoURL = generateEncodedVideoURL(
      screenRecordURL: screenRecordURL,
      encodingPreset: encodingPreset
    )
    if fileManager.fileExists(atPath: encodedVideoURL.path()) {
      return encodedVideoURL
    } else {
      return nil
    }
  }

  func removeFileIfExists(url urlRef: URL?) {
    guard let url = urlRef else { return }
    if fileManager.fileExists(atPath: url.path()) {
      try? fileManager.removeItem(at: url)
    }
  }

  private func getEncodedVideoCollection(_ screenRecordURL: URL) -> EncodedVideoCollection {
    let pairs = EncodingPreset.allPresets.flatMap { preset in
      guard
        let url = getEncodedVideoURL(
          screenRecordURL: screenRecordURL,
          encodingPreset: preset
        )
      else {
        return [(EncodingPreset, URL)]()
      }
      return [(preset, url)]
    }
    return EncodedVideoCollection(
      encodedVideoURLs: Dictionary(uniqueKeysWithValues: pairs)
    )
  }

  func removeScreenRecord(_ screenRecordEntry: ScreenRecordEntry) {
    try? fileManager.removeItem(at: screenRecordEntry.url)
  }

  func removeEncodedVideos(_ screenRecordEntry: ScreenRecordEntry) {
    for preset in EncodingPreset.allPresets {
      let url = generateEncodedVideoURL(
        screenRecordURL: screenRecordEntry.url, encodingPreset: preset)
      try? fileManager.removeItem(at: url)
    }
  }

  func removeThumbnail(_ screenRecordEntry: ScreenRecordEntry) {
    let url = paths.getThumbnailURL(screenRecordEntry.url)
    try? fileManager.removeItem(at: url)
  }

  func removePreviewVideo(_ screenRecordEntry: ScreenRecordEntry) {
    let url = paths.getPreviewVideoURL(screenRecordEntry.url)
    try? fileManager.removeItem(at: url)
  }
}

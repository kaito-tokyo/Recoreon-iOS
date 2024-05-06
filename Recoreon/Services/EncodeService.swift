import Foundation

protocol EncodeService {
  func generateEncodedVideoURL(screenRecordEntry: ScreenRecordEntry, preset: EncodingPreset) -> URL
  func removeEncodedVideo(encodedVideoEntry: EncodedVideoEntry)
  func encode(
    screenRecordEntry: ScreenRecordEntry, preset: EncodingPreset,
    progressHandler: @escaping (Double, Double) -> Void
  ) async -> EncodedVideoEntry?
}

import Foundation

private let paths = RecoreonPaths()
private let fileManager = FileManager.default

class RecordedVideoManipulatorImpl: RecordedVideoManipulatorProtocol {
  private let videoEncoder = VideoEncoder()

  func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async
    -> Bool {
    paths.ensureAppGroupDirectoriesExists()

    let encodedVideoURL = paths.getEncodedVideoURL(recordedVideoURL, suffix: "-discord")
    let isSuccessful = await videoEncoder.encode(
      recordedVideoURL, outputURL: encodedVideoURL, progressHandler: progressHandler)
    if isSuccessful {
      UISaveVideoAtPathToSavedPhotosAlbum(encodedVideoURL.path(), nil, nil, nil)
      return true
    } else {
      return false
    }
  }

  func publishRecordedVideo(_ recordedVideoURL: URL) -> Bool {
    paths.ensureAppGroupDirectoriesExists()
    paths.ensureSharedDirectoriesExists()

    let sharedRecordedVideoURL = paths.getSharedRecordedVideoURL(recordedVideoURL)
    do {
      try fileManager.copyItem(at: recordedVideoURL, to: sharedRecordedVideoURL)
      return true
    } catch {
      return false
    }
  }
}

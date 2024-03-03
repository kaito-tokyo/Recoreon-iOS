import RecoreonCommon

struct PreviewEncodeService: EncodeService {
  private let fileManager: FileManager
  private let recoreonPathService: RecoreonPathService
  private let defaultImpl: EncodeService
  private var finishSucessfully = false

  init(
    fileManager: FileManager,
    recoreonPathService: RecoreonPathService
  ) {
    self.fileManager = fileManager
    self.recoreonPathService = recoreonPathService
    self.defaultImpl = DefaultEncodeService(
      fileManager: fileManager, recoreonPathService: recoreonPathService)
  }

  func generateEncodedVideoURL(
    screenRecordEntry: ScreenRecordEntry,
    preset: EncodingPreset
  ) -> URL {
    return defaultImpl.generateEncodedVideoURL(screenRecordEntry: screenRecordEntry, preset: preset)
  }

  func removeEncodedVideo(encodedVideoEntry: EncodedVideoEntry) {
    defaultImpl.removeEncodedVideo(encodedVideoEntry: encodedVideoEntry)
  }

  func encode(
    screenRecordEntry: ScreenRecordEntry,
    preset: EncodingPreset,
    progressHandler: @escaping (Double, Double) -> Void
  ) async -> EncodedVideoEntry? {
    progressHandler(0.3, 1.0)
    sleep(1)
    progressHandler(0.5, 1.0)
    sleep(1)
    progressHandler(0.7, 1.0)
    sleep(1)
    progressHandler(1.1, 1.0)
    let encodedVideoURL = URL(filePath: "1.mp4")
    let encodedVideoEntry = EncodedVideoEntry(url: encodedVideoURL, preset: preset)
    return encodedVideoEntry
  }
}

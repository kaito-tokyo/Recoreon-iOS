class EncodeServiceMock: EncodeService {
  init() {
    let fileManager = FileManager.default
    let recoreonPathService = RecoreonPathService(fileManager: fileManager)
    super.init(fileManager: fileManager, recoreonPathService: recoreonPathService)
  }

  var finishSucessfully = false

  override func encode(
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
    finishSucessfully.toggle()
    if finishSucessfully {
      let encodedVideoURL = URL(filePath: "1.mp4")
      let encodedVideoEntry = EncodedVideoEntry(url: encodedVideoURL, preset: preset)
      return encodedVideoEntry
    } else {
      return nil
    }
  }
}

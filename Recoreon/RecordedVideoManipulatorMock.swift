class RecordedVideoManipulatorMock: RecordedVideoManipulatorProtocol {
  func listVideoEntries() -> [RecordedVideoEntry] {
    let uiImage = UIImage(named: "AppIcon")!

    return (0..<30).map {
      RecordedVideoEntry(url: URL(fileURLWithPath: "\($0).mkv"), uiImage: uiImage)
    }
  }

  var finishSucessfully = false

  func encode(
    preset: EncodingPreset,
    recordedVideoURL: URL, progressHandler: @escaping (Double, Double) -> Void
  ) async -> URL? {
    progressHandler(0.3, 1.0)
    sleep(1)
    progressHandler(0.3, 1.0)
    sleep(1)
    progressHandler(0.5, 1.0)
    sleep(1)
    progressHandler(0.7, 1.0)
    sleep(1)
    progressHandler(1.1, 1.0)
    finishSucessfully.toggle()
    if finishSucessfully {
      return URL(filePath: "1.mp4")
    } else {
      return nil
    }
  }

  func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async
    -> Bool
  {  // swiftlint:disable:this opening_brace
    progressHandler(0.3)
    sleep(1)
    progressHandler(0.5)
    sleep(1)
    progressHandler(0.7)
    sleep(1)
    progressHandler(1.1)
    sleep(1)
    finishSucessfully.toggle()
    return finishSucessfully
  }

  func publishRecordedVideo(_ recordedVideoURL: URL) -> Bool {
    finishSucessfully.toggle()
    return finishSucessfully
  }
}

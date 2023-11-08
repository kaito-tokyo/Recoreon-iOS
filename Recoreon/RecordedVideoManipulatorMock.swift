class RecordedVideoManipulatorMock: RecordedVideoManipulatorProtocol {
  func listVideoEntries() -> [RecordedVideoEntry] {
    let uiImage = UIImage(named: "AppIcon")!

    return (0..<30).map {
      RecordedVideoEntry(url: URL(fileURLWithPath: "\($0).mkv"), uiImage: uiImage)
    }
  }

  var finishSucessfully = false

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

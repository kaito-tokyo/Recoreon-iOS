protocol RecordedVideoManipulatorProtocol {
  func listVideoEntries() -> [RecordedVideoEntry]
  func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async
    -> Bool
  func publishRecordedVideo(_ recordedVideoURL: URL) -> Bool
}

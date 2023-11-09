protocol RecordedVideoManipulator {
  func listVideoEntries() -> [RecordedVideoEntry]
  func encode(
    preset: EncodingPreset,
    recordedVideoURL: URL,
    progressHandler: @escaping (Double, Double) -> Void
  ) async -> URL?
  func publishRecordedVideo(_ recordedVideoURL: URL) -> Bool
  func remux(_ recordedVideoURL: URL) async -> URL?
}

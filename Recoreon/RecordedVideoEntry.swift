struct RecordedVideoEntry: Identifiable {
  let url: URL
  let uiImage: UIImage

  var id: URL { url }
}

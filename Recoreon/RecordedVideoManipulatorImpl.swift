import Foundation

private let paths = RecoreonPaths()
private let fileManager = FileManager.default

class RecordedVideoManipulatorImpl: RecordedVideoManipulatorProtocol {
  private let thumbnailExtractor = ThumbnailExtractor()
  private let videoEncoder = VideoEncoder()

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

  func listVideoEntries() -> [RecordedVideoEntry] {
    paths.ensureAppGroupDirectoriesExists()

    return paths.listRecordURLs().flatMap { recordedVideoURL -> [RecordedVideoEntry] in
      let thumbnailURL = paths.getThumbnailURL(recordedVideoURL)
      if !fileManager.fileExists(atPath: thumbnailURL.path()) {
        thumbnailExtractor.extract(recordedVideoURL, thumbnailURL: thumbnailURL)
      }
      guard let uiImage = UIImage(contentsOfFile: thumbnailURL.path()) else { return [] }
      guard let cgImage = uiImage.cgImage else { return [] }
      guard let cropped = cropCGImage(cgImage) else { return [] }
      return [RecordedVideoEntry(url: recordedVideoURL, uiImage: UIImage(cgImage: cropped))]
    }
  }

  func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async
    -> Bool
  { // swiftlint:disable:this opening_brace
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

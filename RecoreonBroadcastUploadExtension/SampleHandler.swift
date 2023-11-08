//
//  SampleHandler.swift
//  RecoreonBroadcastUploadExtension
//
//  Created by Kaito Udagawa on 2023/11/02.
//

import ReplayKit

private let paths = RecoreonPaths()

class SampleHandler: RPBroadcastSampleHandler {
  private let fileManager = FileManager.default
  var writer: MediaWriter?
  var newPixelBufferRef: CVPixelBuffer?
  let ciContext = CIContext()
  var audioBufferList = AudioBufferList()
  let dateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current
    return formatter
  }()

  func generateFileName(date: Date, ext: String = "mkv") -> String {
    let dateString = dateFormatter.string(from: date)
    return "Recoreon\(dateString).\(ext)"
  }

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    paths.ensureAppGroupDirectoriesExists()

    writer = MediaWriter()
    let url = paths.recordsDir.appending(
      path: generateFileName(date: Date()), directoryHint: .notDirectory)
    writer?.open(url.path())
  }

  override func broadcastPaused() {
    // User has requested to pause the broadcast. Samples will stop being delivered.
  }

  override func broadcastResumed() {
    // User has requested to resume the broadcast. Samples delivery will resume.
  }

  override func broadcastFinished() {
    writer?.close()
  }

  func checkIfNewPixelBufferShouldBeRecreate(_ origWidth: Int, _ origHeight: Int) -> Bool {
    guard let newPixelBuffer = newPixelBufferRef else { return true }
    let newWidth = CVPixelBufferGetWidth(newPixelBuffer)
    let newHeight = CVPixelBufferGetHeight(newPixelBuffer)
    return newWidth != origWidth || newHeight != origHeight
  }

  func renderToNewPixelBuffer(_ origPixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
    let width = CVPixelBufferGetWidth(origPixelBuffer)
    let height = CVPixelBufferGetHeight(origPixelBuffer)
    if checkIfNewPixelBufferShouldBeRecreate(width, height) {
      CVPixelBufferCreate(
        nil, width, height, kCVPixelFormatType_420YpCbCr8BiPlanarFullRange, nil, &newPixelBufferRef)
    }
    guard let newPixelBuffer = newPixelBufferRef else { return nil }
    let ciImage = CIImage(cvPixelBuffer: origPixelBuffer)
    ciContext.render(ciImage, to: newPixelBuffer)
    ciContext.clearCaches()
    return newPixelBuffer
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType
  ) {
    switch sampleBufferType {
    case RPSampleBufferType.video:
      guard let origPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        print("Could not obtain the pixel buffer!")
        return
      }
      guard let newPixelBuffer = renderToNewPixelBuffer(origPixelBuffer) else {
        print("Could not render to the pixel buffer!")
        return
      }
      self.writer?.writeVideo(ofScreen: sampleBuffer, pixelBuffer: newPixelBuffer)
    case RPSampleBufferType.audioApp:
      var blockBuffer: CMBlockBuffer?
      CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: &audioBufferList,
        bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil,
        blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &blockBuffer)
      self.writer?.writeAudio(ofScreen: sampleBuffer, audioBufferList: &self.audioBufferList)
    case RPSampleBufferType.audioMic:
      var blockBuffer: CMBlockBuffer?
      CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer, bufferListSizeNeededOut: nil, bufferListOut: &audioBufferList,
        bufferListSize: MemoryLayout<AudioBufferList>.size, blockBufferAllocator: nil,
        blockBufferMemoryAllocator: nil, flags: 0, blockBufferOut: &blockBuffer)
      self.writer?.writeAudio(ofMic: sampleBuffer, audioBufferList: &self.audioBufferList)
    @unknown default:
      // Handle other sample buffer types
      fatalError("Unknown type of sample buffer")
    }
  }
}

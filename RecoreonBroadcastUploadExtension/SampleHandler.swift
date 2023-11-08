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
  var audioBufferList = AudioBufferList()
  let dateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current
    return formatter
  }()
  let pixelBufferExtractorRef = PixelBufferExtractor()

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

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType
  ) {
    switch sampleBufferType {
    case RPSampleBufferType.video:
      guard let origPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        print("Could not obtain the pixel buffer!")
        return
      }
      guard let newPixelBuffer = pixelBufferExtractorRef?.extract(origPixelBuffer) else {
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

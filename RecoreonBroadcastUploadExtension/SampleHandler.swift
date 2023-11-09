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
    let url = paths.appGroupRecordsDir.appending(
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

  func getLumaBytesPerRow(_ pixelBuffer: CVPixelBuffer) -> Int {
    if let desired = writer?.desiredLumaBytesPerRow {
      if desired != 0 {
        return desired
      }
    }
    return CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
  }

  func getChromaBytesPerRow(_ pixelBuffer: CVPixelBuffer) -> Int {
    if let desired = writer?.desiredChromaBytesPerRow {
      if desired != 0 {
        return desired
      }
    }
    return CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType
  ) {
    switch sampleBufferType {
    case RPSampleBufferType.video:
      guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        print("Could not obtain the pixel buffer!")
        return
      }
      let lumaBytesPerRow = getLumaBytesPerRow(pixelBuffer)
      let chromaBytesPerRow = getChromaBytesPerRow(pixelBuffer)
      guard
        let frame = pixelBufferExtractorRef?.extract(
          pixelBuffer, lumaBytesPerRow: lumaBytesPerRow, chromaBytesPerRow: chromaBytesPerRow)
      else {
        print("Could not render to the pixel buffer!")
        return
      }
      self.writer?.writeVideo(
        ofScreen: sampleBuffer, pixelBuffer: pixelBuffer, lumaData: frame.lumaData,
        chromaData: frame.chmoraData, lumaBytesPerRow: frame.lumaBytesPerRow,
        chromaBytesPerRow: frame.chromaBytesPerRow)
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

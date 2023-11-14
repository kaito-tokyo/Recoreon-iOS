//
//  SampleHandler.swift
//  RecoreonBroadcastUploadExtension
//
//  Created by Kaito Udagawa on 2023/11/02.
//

import ReplayKit

private let paths = RecoreonPaths()

class SampleHandler: RPBroadcastSampleHandler {
  let frameRate = 120

  private let fileManager = FileManager.default
  var writer = ScreenRecordWriter()
  let dateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions.remove(.withDashSeparatorInDate)
    formatter.formatOptions.remove(.withColonSeparatorInTime)
    formatter.formatOptions.remove(.withTimeZone)
    formatter.timeZone = TimeZone.current
    return formatter
  }()
  let pixelBufferExtractorRef = PixelBufferExtractor()

  var isOutputStarted: Bool = false

  var screenBasePTS: Int64 = 0
  var micBasePTS: Int64 = 0

  func generateFileName(date: Date, ext: String = "mkv") -> String {
    let dateString = dateFormatter.string(from: date)
    return "Recoreon\(dateString).\(ext)"
  }

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    paths.ensureAppGroupDirectoriesExists()

    let url = paths.appGroupRecordsDir.appending(
      path: generateFileName(date: Date()), directoryHint: .notDirectory)
    writer.openVideoCodec("h264_videotoolbox")
    writer.openAudioCodec("aac_at")
  }

  override func broadcastPaused() {
    // User has requested to pause the broadcast. Samples will stop being delivered.
  }

  override func broadcastResumed() {
    // User has requested to resume the broadcast. Samples delivery will resume.
  }

  override func broadcastFinished() {
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType
  ) {
    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    switch sampleBufferType {
    case RPSampleBufferType.video:
      guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
        print("Could not obtain the pixel buffer!")
        return
      }

      let width = Int32(CVPixelBufferGetWidth(pixelBuffer))
      let height = Int32(CVPixelBufferGetHeight(pixelBuffer))

      if !isOutputStarted {
        writer.addVideoStream(0, width: width, height: height, frameRate: frameRate, bitRate: 8000000)
        writer.addAudioStream(1, sampleRate: 44100, bitRate: 320000)
        writer.addAudioStream(2, sampleRate: 48000, bitRate: 320000)
        writer.openVideo(0)
        writer.openAudio(1)
        writer.openAudio(2)
        writer.startOutput()

        screenBasePTS = pts.value
      }

      let lumaBytesPerRow = Int(writer.getBytesPerRow(0, planeIndex: 0))
      let chromaBytesPerRow = Int(writer.getBytesPerRow(0, planeIndex: 1))
      guard
        let frame = pixelBufferExtractorRef?.extract(
          pixelBuffer, lumaBytesPerRow: lumaBytesPerRow, chromaBytesPerRow: chromaBytesPerRow)
      else {
        print("Could not render to the pixel buffer!")
        return
      }

      let outputPTS = (pts.value - screenBasePTS) * frameRate / Int64(pts.timescale)
      writer.writeVideo(0, lumaData: frame.lumaData, chromaData: frame.chmoraData, lumaBytesPerRow: frame.lumaBytesPerRow, chromaBytesPerRow: frame.chromaBytesPerRow, height: frame.height, outputPTS: outputPTS)
    case RPSampleBufferType.audioApp:
      if !isOutputStarted {
        return
      }

      var blockBuffer: CMBlockBuffer?
      var abl: AudioBufferList
      CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        bufferListSizeNeededOut: nil,
        bufferListOut: &abl,
        bufferListSize: MemoryLayout<AudioBufferList>.size,
        blockBufferAllocator: nil,
        blockBufferMemoryAllocator: nil, 
        flags: 0,
        blockBufferOut: &blockBuffer
      )
      guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
      guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }
      let outputPTS = (pts.value - screenBasePTS) * 44100 / Int64(pts.timescale)
      writer.writeAudio(1, abl: &abl, asbd: asbd, outputPTS: outputPTS)
    case RPSampleBufferType.audioMic:
      if !isOutputStarted {
        return
      }

      if micBasePTS == 0 {
        micBasePts = pts.value - screenBasePTS * ptsTime.timescale / frameRate
      }

      var blockBuffer: CMBlockBuffer?
      var abl: AudioBufferList
      CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
        sampleBuffer,
        bufferListSizeNeededOut: nil,
        bufferListOut: &abl,
        bufferListSize: MemoryLayout<AudioBufferList>.size,
        blockBufferAllocator: nil,
        blockBufferMemoryAllocator: nil,
        flags: 0,
        blockBufferOut: &blockBuffer
      )
      guard let format = CMSampleBufferGetFormatDescription(sampleBuffer) else { return }
      guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format) else { return }
      let outputPTS = (pts.value - micBasePTS) * 48000 / Int64(pts.timescale)
      writer.writeAudio(1, abl: &abl, asbd: asbd, outputPTS: outputPTS)
    @unknown default:
      // Handle other sample buffer types
      fatalError("Unknown type of sample buffer")
    }
  }
}

//
//  SampleHandler.swift
//  RecoreonBroadcastUploadExtension
//
//  Created by Kaito Udagawa on 2023/11/02.
//

import ReplayKit

private let paths = RecoreonPaths()

private let fileManager = FileManager.default

private let dateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions.remove(.withDashSeparatorInDate)
  formatter.formatOptions.remove(.withColonSeparatorInTime)
  formatter.formatOptions.remove(.withTimeZone)
  formatter.timeZone = TimeZone.current
  return formatter
}()

class SampleHandler: RPBroadcastSampleHandler {
  let frameRate: Int32 = 120

  let writer = ScreenRecordWriter()
  let pixelBufferExtractorRef = PixelBufferExtractor()
  var screenAudioBufferHandler: AudioBufferHandler?
  var micAudioBufferHandler: AudioBufferHandler?

  var isOutputStarted: Bool = false

  var screenFirstTime: CMTime?
  var screenElapsedTime: CMTime?
  var micFirstTime: CMTime?

  let queue = DispatchQueue(label: "com.github.umireon.Recoreon.com.github.umireon.Recoreon.queue")

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
    writer.openOutputFile(url.path())
  }

  override func broadcastPaused() {
    // User has requested to pause the broadcast. Samples will stop being delivered.
  }

  override func broadcastResumed() {
    // User has requested to resume the broadcast. Samples delivery will resume.
  }

  override func broadcastFinished() {
    writer.finishStream(0)
    writer.finishStream(1)
    writer.finishStream(2)
    writer.finishOutput()
    writer.freeStream(0)
    writer.freeStream(1)
    writer.freeStream(2)
    writer.freeOutput()
  }

  func handleVideoSample(index: Int32, pixelBuffer: CVPixelBuffer, outputPTS: Int64) {
    let lumaBytesPerRow = Int(writer.getBytesPerRow(0, planeIndex: 0))
    let chromaBytesPerRow = Int(writer.getBytesPerRow(0, planeIndex: 1))
    guard
      let frame = pixelBufferExtractorRef?.extract(
        pixelBuffer, lumaBytesPerRow: lumaBytesPerRow, chromaBytesPerRow: chromaBytesPerRow)
    else {
      print("Could not render to the pixel buffer!")
      return
    }

    queue.async {
      self.writer.writeVideo(
        0,
        lumaData: frame.lumaData,
        chromaData: frame.chmoraData,
        lumaBytesPerRow: frame.lumaBytesPerRow,
        chromaBytesPerRow: frame.chromaBytesPerRow,
        height: frame.height,
        outputPTS: outputPTS
      )
    }
  }

  func handleScreenAudioSample(index: Int32, sampleBuffer: CMSampleBuffer, outputPTS: Int64) {
    var blockBuffer: CMBlockBuffer?
    var abl = AudioBufferList()
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
    guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
      return
    }
    guard let bufferHandler = screenAudioBufferHandler else { return }

    if abl.mBuffers.mDataByteSize != bufferHandler.byteCount {
      return
    }

    guard let data = abl.mBuffers.mData else { return }

    if asbd.mSampleRate == 44100 {
      if asbd.mChannelsPerFrame == 2 {
        if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
          bufferHandler.copyStereoToStereo(from: data)
        } else {
          bufferHandler.copyStereoToStereoWithSwap(from: data)
        }
      } else {
        return
      }
    } else {
      print(asbd.mSampleRate)
      return
    }
    writer.writeAudio(1, outputPTS: outputPTS)
  }

  func handleMicAudioSample(index: Int32, sampleBuffer: CMSampleBuffer, outputPTS: Int64) {
    var blockBuffer: CMBlockBuffer?
    var abl = AudioBufferList()
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
    guard let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee else {
      return
    }
    guard let bufferHandler = micAudioBufferHandler else { return }

    if abl.mBuffers.mDataByteSize != bufferHandler.byteCount {
      return
    }

    guard let inData = abl.mBuffers.mData else { return }
    if asbd.mSampleRate == 48000 {
      if asbd.mChannelsPerFrame == 1 {
        if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
          bufferHandler.copyMonoToStereoWithSwap(from: inData)
        } else {
          return
        }
      } else {
        return
      }
    } else {
      return
    }
    writer.writeAudio(1, outputPTS: outputPTS)
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
        writer.addVideoStream(
          0, width: width, height: height, frameRate: frameRate, bitRate: 8_000_000)
        writer.addAudioStream(1, sampleRate: 44100, bitRate: 320000)
        writer.addAudioStream(2, sampleRate: 48000, bitRate: 320000)
        writer.openVideo(0)
        writer.openAudio(1)
        writer.openAudio(2)
        writer.startOutput()

        screenAudioBufferHandler = AudioBufferHandler(
          buf: writer.getMemoryOfPlane(1, planeIndex: 0),
          byteCount: writer.getByteCount(ofAudioPlane: 1)
        )
        micAudioBufferHandler = AudioBufferHandler(
          buf: writer.getMemoryOfPlane(2, planeIndex: 0),
          byteCount: writer.getByteCount(ofAudioPlane: 2)
        )

        isOutputStarted = true
        screenFirstTime = pts
      }

      guard let firstTime = self.screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      self.screenElapsedTime = elapsedTime
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: frameRate)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)
      print("V: \(outputPTS)")

      self.handleVideoSample(index: 0, pixelBuffer: pixelBuffer, outputPTS: outputPTS)
    case RPSampleBufferType.audioApp:
      if !isOutputStarted {
        return
      }

      guard let firstTime = screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: 44100)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)
      print("A: \(outputPTS)")

      self.handleScreenAudioSample(index: 1, sampleBuffer: sampleBuffer, outputPTS: outputPTS)
    case RPSampleBufferType.audioMic:
      if !isOutputStarted {
        return
      }

      if micFirstTime == nil {
        guard let elapsedTime = screenElapsedTime else { return }
        micFirstTime = CMTimeSubtract(pts, elapsedTime)
      }
      guard let firstTime = micFirstTime else { return }
      let elapsedCount = CMTimeMultiply(CMTimeSubtract(pts, firstTime), multiplier: 48000)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      self.handleMicAudioSample(index: 2, sampleBuffer: sampleBuffer, outputPTS: outputPTS)
    @unknown default:
      // Handle other sample buffer types
      fatalError("Unknown type of sample buffer")
    }
  }
}

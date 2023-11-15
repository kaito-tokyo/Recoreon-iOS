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
  let frameRate = 120

  let writer = ScreenRecordWriter()
  let pixelBufferExtractorRef = PixelBufferExtractor()
  var screenAudioBufferHandler: AudioBufferHandler?
  var micAudioBufferHandler: AudioBufferHandler?

  var isOutputStarted: Bool = false

  var screenFirstTime: CMTime?
  var screenElapsedTime: CMTime?
  var micFirstTime: CMTime?

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
    writer.closeStream(0)
    writer.closeStream(1)
    writer.closeStream(2)
    writer.closeOutput()
  }

  func handleVideoSample(index: Int32, pixelBuffer: CVPixelBuffer, outputPTS: Int64) {
    let lumaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 0)
    let chromaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 1)
    guard
      let frame = pixelBufferExtractorRef?.extract(
        pixelBuffer, lumaBytesPerRow: lumaBytesPerRow, chromaBytesPerRow: chromaBytesPerRow)
    else {
      print("Could not render to the pixel buffer!")
      return
    }
    writer.writeVideo(0, outputPTS: outputPTS)
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

    writer.makeFrameWritable(1)
    let frameBuf = writer.getBaseAddress(1, ofPlane: 0)
    if asbd.mSampleRate == 44100 {
      if asbd.mChannelsPerFrame == 2 {
        if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
          bufferHandler.copyStereoToStereo(from: data, to: frameBuf)
        } else {
          bufferHandler.copyStereoToStereoWithSwap(from: data, to: frameBuf)
        }
      } else {
        return
      }
    } else {
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

    writer.makeFrameWritable(2)
    let frameBuf = writer.getBaseAddress(2, ofPlane: 0)

    if abl.mBuffers.mDataByteSize != bufferHandler.byteCount {
      return
    }

    guard let inData = abl.mBuffers.mData else { return }
    if asbd.mSampleRate == 48000 {
      if asbd.mChannelsPerFrame == 1 {
        if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian != 0 {
          bufferHandler.copyMonoToStereoWithSwap(from: inData, to: frameBuf)
        } else {
          return
        }
      } else {
        return
      }
    } else {
      return
    }
    writer.writeAudio(2, outputPTS: outputPTS)
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

      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)

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
          byteCount: writer.getNumSamples(1) * 4
        )
        micAudioBufferHandler = AudioBufferHandler(
          byteCount: writer.getNumSamples(2) * 4
        )

        isOutputStarted = true
        screenFirstTime = pts
      }

      guard let firstTime = self.screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      self.screenElapsedTime = elapsedTime
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: Int32(frameRate))
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      self.handleVideoSample(index: 0, pixelBuffer: pixelBuffer, outputPTS: outputPTS)
    case RPSampleBufferType.audioApp:
      if !isOutputStarted {
        return
      }

      guard let firstTime = screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: 44100)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

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

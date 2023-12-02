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

// swiftlint:disable function_parameter_count
private func copyPlane(
  fromData: UnsafeRawPointer,
  toData: UnsafeMutableRawPointer,
  width: Int,
  height: Int,
  fromBytesPerRow: Int,
  toBytesPerRow: Int
) {
  if fromBytesPerRow == toBytesPerRow {
    toData.copyMemory(from: fromData, byteCount: fromBytesPerRow * height)
  } else {
    for yIndex in 0..<height {
      let src = fromData.advanced(by: fromBytesPerRow * yIndex)
      let dest = toData.advanced(by: toBytesPerRow * yIndex)
      dest.copyMemory(from: src, byteCount: width)
    }
  }
}
// swiftlint:enable function_parameter_count

// swiftlint:disable type_body_length function_body_length cyclomatic_complexity
class SampleHandler: RPBroadcastSampleHandler {
  struct Spec {
    let frameRate: Int
    let videoBitRate: Int
    let screenAudioSampleRate: Int
    let screenAudioBitRate: Int
    let micAudioSampleRate: Int
    let micAudioBitRate: Int
  }

  let spec = Spec(
    frameRate: 60,
    videoBitRate: 8_000_000,
    screenAudioSampleRate: 44100,
    screenAudioBitRate: 320_000,
    micAudioSampleRate: 48000,
    micAudioBitRate: 320_000
  )

  let writer = ScreenRecordWriter()
  var pixelBufferExtractorRef: PixelBufferExtractor?
  var screenSameRateSampler: Int16SameRateSampler?
  var micSameRateSampler: Int16SameRateSampler?
  var micDoubleUpsampler: Int16DoubleUpsampler?
  let micAudioBuf = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 2)

  var isOutputStarted: Bool = false

  var screenFirstTime: CMTime?
  var screenElapsedTime: CMTime?
  var micFirstTime: CMTime?

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    startRecording()
  }

  override func broadcastPaused() {
    // User has requested to pause the broadcast. Samples will stop being delivered.
  }

  override func broadcastResumed() {
    // User has requested to resume the broadcast. Samples delivery will resume.
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType
  ) {
    switch sampleBufferType {
    case RPSampleBufferType.video:
      processScreenVideoSample(sampleBuffer)
    case RPSampleBufferType.audioApp:
      processScreenAudioSample(sampleBuffer)
    case RPSampleBufferType.audioMic:
      processMicAudioSample(sampleBuffer)
    @unknown default:
      fatalError("Unknown type of sample buffer")
    }
  }

  override func broadcastFinished() {
    stopRecording()
  }

  func generateFileName(date: Date, ext: String = "mkv") -> String {
    let dateString = dateFormatter.string(from: date)
    return "Recoreon\(dateString).\(ext)"
  }

  func startRecording() {
    paths.ensureAppGroupDirectoriesExists()

    let url = paths.appGroupRecordsDir.appending(
      path: generateFileName(date: Date()), directoryHint: .notDirectory)
    writer.openVideoCodec("h264_videotoolbox")
    writer.openAudioCodec("aac_at")
    writer.openOutputFile(url.path())
  }

  func initAllStreams(width: Int, height: Int) {
    writer.addVideoStream(
      0, width: width, height: height, frameRate: spec.frameRate, bitRate: spec.videoBitRate)
    writer.addAudioStream(
      1, sampleRate: spec.screenAudioSampleRate, bitRate: spec.screenAudioBitRate)
    writer.addAudioStream(2, sampleRate: spec.micAudioSampleRate, bitRate: spec.micAudioBitRate)
    writer.openVideo(0)
    writer.openAudio(1)
    writer.openAudio(2)
    writer.startOutput()

    let lumaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 0)
    let chromaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 1)
    pixelBufferExtractorRef = PixelBufferExtractor(
      height: height,
      lumaBytesPerRow: lumaBytesPerRow,
      chromaBytesPerRow: chromaBytesPerRow
    )

    screenSameRateSampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(1))
    micSameRateSampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(2))
    micDoubleUpsampler = Int16DoubleUpsampler(toNumSamples: writer.getNumSamples(2))
  }

  func processScreenVideoSample(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    if !isOutputStarted {
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
      initAllStreams(width: width, height: height)
      isOutputStarted = true
    }

    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if screenFirstTime == nil {
      screenFirstTime = pts
    }
    guard let firstTime = self.screenFirstTime else { return }
    let elapsedTime = CMTimeSubtract(pts, firstTime)
    let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: Int32(spec.frameRate))
    let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)
    screenElapsedTime = elapsedTime

    writeVideoFrame(index: 0, pixelBuffer, outputPTS: outputPTS)
  }

  func writeVideoFrame(index: Int, _ pixelBuffer: CVPixelBuffer, outputPTS: Int64) {
    guard let frame = pixelBufferExtractorRef?.extract(pixelBuffer) else { return }

    writer.makeFrameWritable(index)

    let width = min(frame.width, writer.getWidth(index))
    let height = min(frame.height, writer.getHeight(index))

    copyPlane(
      fromData: frame.lumaData,
      toData: writer.getBaseAddress(index, ofPlane: 0),
      width: width,
      height: height,
      fromBytesPerRow: frame.lumaBytesPerRow,
      toBytesPerRow: writer.getBytesPerRow(index, ofPlane: 0)
    )

    copyPlane(
      fromData: frame.chromaData,
      toData: writer.getBaseAddress(index, ofPlane: 1),
      width: width,
      height: height / 2,
      fromBytesPerRow: frame.chromaBytesPerRow,
      toBytesPerRow: writer.getBytesPerRow(index, ofPlane: 1)
    )

    writer.writeVideo(index, outputPTS: outputPTS)
  }

  func processScreenAudioSample(_ sampleBuffer: CMSampleBuffer) {
    let index = 1
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

    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    guard let firstTime = screenFirstTime else { return }
    let elapsedTime = CMTimeSubtract(pts, firstTime)
    let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: Int32(spec.screenAudioSampleRate))
    var outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

    guard
      let format = CMSampleBufferGetFormatDescription(sampleBuffer),
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee
    else { return }

    if abl.mBuffers.mDataByteSize != writer.getNumSamples(index) * 4 {
      print("Sample size invalid")
      return
    }

    var resamplerRef: AudioResampler?
    if Int(asbd.mSampleRate) == spec.screenAudioSampleRate {
      resamplerRef = screenSameRateSampler
    }
    guard var resampler = resamplerRef else { return }

    resampler.reset()
    guard let fromData = abl.mBuffers.mData else { return }
    resampler.fromData = UnsafeRawPointer(fromData)
    resampler.fromNumSamples = Int(abl.mBuffers.mDataByteSize / abl.mBuffers.mNumberChannels / 2)
    if asbd.mChannelsPerFrame == 1 {
      if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
        resampler.copyOperationMode = .monoToStereo
      } else {
        resampler.copyOperationMode = .monoToStereoWithSwap
      }
    } else if asbd.mChannelsPerFrame == 2 {
      if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
        resampler.copyOperationMode = .stereoToStereo
      } else {
        resampler.copyOperationMode = .stereoToStereoWithSwap
      }
    } else {
      return
    }
    while resampler.hasNext() {
      writer.makeFrameWritable(index)
      resampler.toData = writer.getBaseAddress(index, ofPlane: 0)
      if !resampler.doCopy() {
        break
      }
      writer.writeAudio(index, outputPTS: outputPTS)
      outputPTS += Int64(writer.getNumSamples(index))
    }
  }

  func processMicAudioSample(_ sampleBuffer: CMSampleBuffer) {
    let index = 2

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

    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    if micFirstTime == nil {
      guard let elapsedTime = screenElapsedTime else { return }
      micFirstTime = CMTimeSubtract(pts, elapsedTime)
    }
    guard let firstTime = micFirstTime else { return }
    let elapsedCount = CMTimeMultiply(
      CMTimeSubtract(pts, firstTime), multiplier: Int32(spec.micAudioSampleRate))
    var outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

    guard
      let format = CMSampleBufferGetFormatDescription(sampleBuffer),
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
      let buf = abl.mBuffers.mData
    else { return }

    var inData: UnsafePointer<UInt8>
    let numBytes = abl.mBuffers.mDataByteSize
    if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
      inData = UnsafePointer<UInt8>(buf.assumingMemoryBound(to: UInt8.self))
    } else {
      let audioBufView = micAudioBuf.assumingMemoryBound(to: UInt16.self)
      let bufView = buf.assumingMemoryBound(to: UInt16.self)
      writer.swapInt16Bytes(audioBufView, from: bufView, numBytes: Int(numBytes))
      inData = UnsafePointer<UInt8>(micAudioBuf.assumingMemoryBound(to: UInt8.self))
    }

    writer.ensureResamplerIsInitialted(index, sampleRate: asbd.mSampleRate, numChannels: asbd.mChannelsPerFrame)
    writer.writeAudio(withResampling: index, outputPTS: outputPTS, inData: inData, inCount: Int32(numBytes))
    writer.flushAudio(withResampling: index)
  }

  func stopRecording() {
    writer.finishStream(0)
    writer.finishStream(1)
    writer.finishStream(2)
    writer.finishOutput()
    writer.closeStream(0)
    writer.closeStream(1)
    writer.closeStream(2)
    writer.closeOutput()
  }
}
// swiftlint:enable type_body_length function_body_length cyclomatic_complexity

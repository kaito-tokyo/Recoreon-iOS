import RecoreonCommon
import ReplayKit

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

enum SampleHandlerError: CustomNSError {
  case videoCodecOpeningError
  case audioCodecOpeningError
  case outputFileOpeningError
  case videoStreamAddingError
  case audioStreamAddingError
  case videoOpeningError
  case audioOpeningError
  case titleSettingError
  case outputStartingError

  var errorUserInfo: [String: Any] {
    switch self {
    case .videoCodecOpeningError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the video codec!"
      ]
    case .audioCodecOpeningError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the audio codec!"
      ]
    case .outputFileOpeningError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the output file!"
      ]
    case .videoStreamAddingError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not add a video stream!"
      ]
    case .audioStreamAddingError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not add an audio stream!"
      ]
    case .videoOpeningError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the video!"
      ]
    case .audioOpeningError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not open the audio!"
      ]
    case .titleSettingError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not set the title!"
      ]
    case .outputStartingError:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not start the output!"
      ]
    }
  }
}

class SampleHandler: RPBroadcastSampleHandler {
  struct Spec {
    let ext: String
    let frameRate: Int
    let videoBitRate: Int
    let screenAudioSampleRate: Int
    let screenAudioBitRate: Int
    let micAudioSampleRate: Int
    let micAudioBitRate: Int
  }

  let spec = Spec(
    ext: "mkv",
    frameRate: 60,
    videoBitRate: 8_000_000,
    screenAudioSampleRate: 44100,
    screenAudioBitRate: 320_000,
    micAudioSampleRate: 48000,
    micAudioBitRate: 320_000
  )

  let recoreonPathService = RecoreonPathService(fileManager: FileManager.default)
  let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults

  let writer = ScreenRecordWriter()
  var pixelBufferExtractorRef: PixelBufferExtractor?
  let swapBuf = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 2)

  var isOutputStarted: Bool = false

  var screenFirstTime: CMTime?
  var screenElapsedTime: CMTime?
  var micFirstTime: CMTime?

  var screenStartupCount = 10
  let screenStartupThrottlingFactor = 2

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
    let ongoingRecordingTimestamp =
      appGroupsUserDefaults?.double(
        forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey
      ) ?? 0
    let now = Date().timeIntervalSince1970
    if now - ongoingRecordingTimestamp > 1 {
      appGroupsUserDefaults?.set(
        Date().timeIntervalSince1970,
        forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey)
    }

    switch sampleBufferType {
    case RPSampleBufferType.video:
      processScreenVideoSample(sampleBuffer)
    case RPSampleBufferType.audioApp:
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      guard let firstTime = screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: Int32(spec.screenAudioSampleRate))
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      processAudioSample(index: 1, outputPTS: outputPTS, sampleBuffer)
    case RPSampleBufferType.audioMic:
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      if micFirstTime == nil {
        guard let elapsedTime = screenElapsedTime else { return }
        micFirstTime = CMTimeSubtract(pts, elapsedTime)
      }
      guard let firstTime = micFirstTime else { return }
      let elapsedCount = CMTimeMultiply(
        CMTimeSubtract(pts, firstTime), multiplier: Int32(spec.micAudioSampleRate))
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      processAudioSample(index: 2, outputPTS: outputPTS, sampleBuffer)
    @unknown default:
      fatalError("Unknown type of sample buffer")
    }
  }

  override func broadcastFinished() {
    stopRecording()
  }

  func startRecording() {
    let recordID = recoreonPathService.generateRecordID(date: Date())
    let appGroupsScreenRecordURL = recoreonPathService.generateAppGroupsScreenRecordURL(
      recordID: recordID, ext: spec.ext)

    appGroupsUserDefaults?.set(
      appGroupsScreenRecordURL.absoluteString,
      forKey: AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey)

    let openVideoCodecResult = writer.openVideoCodec("h264_videotoolbox")
    if !openVideoCodecResult {
      finishBroadcastWithError(SampleHandlerError.videoCodecOpeningError)
      return
    }

    let openAudioCodecResult = writer.openAudioCodec("aac_at")
    if !openAudioCodecResult {
      finishBroadcastWithError(SampleHandlerError.audioCodecOpeningError)
      return
    }

    let openOutputFileResult = writer.openOutputFile(appGroupsScreenRecordURL.path())
    if !openOutputFileResult {
      finishBroadcastWithError(SampleHandlerError.outputFileOpeningError)
      return
    }
  }

  func initAllStreams(width: Int, height: Int) {
    let addVideoStream0Result = writer.addVideoStream(
      0, width: width, height: height, frameRate: spec.frameRate, bitRate: spec.videoBitRate)
    if !addVideoStream0Result {
      finishBroadcastWithError(SampleHandlerError.videoStreamAddingError)
      return
    }

    let addAudioStream1Result = writer.addAudioStream(
      1, sampleRate: spec.screenAudioSampleRate, bitRate: spec.screenAudioBitRate)
    if !addAudioStream1Result {
      finishBroadcastWithError(SampleHandlerError.audioStreamAddingError)
      return
    }

    let addAudioStream2Result = writer.addAudioStream(
      2, sampleRate: spec.micAudioSampleRate, bitRate: spec.micAudioBitRate)
    if !addAudioStream2Result {
      finishBroadcastWithError(SampleHandlerError.audioStreamAddingError)
      return
    }

    let setTitle1Result = writer.setTitle(1, value: "App")
    if !setTitle1Result {
      print(SampleHandlerError.titleSettingError)
      finishBroadcastWithError(SampleHandlerError.titleSettingError)
      return
    }

    let setTitle2Result = writer.setTitle(2, value: "Mic")
    if !setTitle2Result {
      print(SampleHandlerError.titleSettingError)
      finishBroadcastWithError(SampleHandlerError.titleSettingError)
      return
    }

    let openVideo0Result = writer.openVideo(0)
    if !openVideo0Result {
      finishBroadcastWithError(SampleHandlerError.videoOpeningError)
      return
    }

    let openAudio1Result = writer.openAudio(1)
    if !openAudio1Result {
      finishBroadcastWithError(SampleHandlerError.audioOpeningError)
      return
    }

    let openAudio2Result = writer.openAudio(2)
    if !openAudio2Result {
      finishBroadcastWithError(SampleHandlerError.audioOpeningError)
      return
    }

    let startOutputResult = writer.startOutput()
    if !startOutputResult {
      finishBroadcastWithError(SampleHandlerError.outputStartingError)
      return
    }

    let lumaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 0)
    let chromaBytesPerRow = writer.getBytesPerRow(0, ofPlane: 1)
    pixelBufferExtractorRef = PixelBufferExtractor(
      height: height,
      lumaBytesPerRow: lumaBytesPerRow,
      chromaBytesPerRow: chromaBytesPerRow
    )
  }

  func processScreenVideoSample(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    if !isOutputStarted {
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
      initAllStreams(width: width, height: height)
      isOutputStarted = true
    }

    if screenStartupCount > 0 {
      let value = screenStartupCount % screenStartupThrottlingFactor
      screenStartupCount -= 1
      if value > 0 {
        return
      }
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

  func processAudioSample(
    index: Int, outputPTS: Int64, _ sampleBuffer: CMSampleBuffer
  ) {
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

    guard
      let format = CMSampleBufferGetFormatDescription(sampleBuffer),
      let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
      let buf = abl.mBuffers.mData
    else { return }

    var inData: UnsafePointer<UInt8>
    let numBytes = abl.mBuffers.mDataByteSize
    let numSamples = numBytes / 2 / asbd.mChannelsPerFrame
    if asbd.mFormatFlags & kAudioFormatFlagIsBigEndian == 0 {
      inData = UnsafePointer<UInt8>(buf.assumingMemoryBound(to: UInt8.self))
    } else {
      let dstView = swapBuf.assumingMemoryBound(to: UInt16.self)
      let srcView = buf.assumingMemoryBound(to: UInt16.self)
      writer.swapInt16Bytes(dstView, from: srcView, numBytes: Int(numBytes))
      inData = UnsafePointer<UInt8>(swapBuf.assumingMemoryBound(to: UInt8.self))
    }

    writer.ensureResamplerIsInitialted(
      index, sampleRate: asbd.mSampleRate, numChannels: asbd.mChannelsPerFrame)
    writer.writeAudio(index, outputPTS: outputPTS, inData: inData, inCount: Int32(numSamples))
    writer.flushAudio(withResampling: index)
  }

  func stopRecording() {
    appGroupsUserDefaults?.set(0, forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey)
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

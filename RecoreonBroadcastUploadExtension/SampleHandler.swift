import CoreMedia
import FragmentedRecordWriter
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

  var videoTranscoder: RealtimeVideoTranscoder?
  var videoWriter: FragmentedVideoWriter?

  var appAudioResampler: AudioResampler?
  var appAudioTranscoder: RealtimeAudioTranscoder?
  var appAudioWriter: FragmentedAudioWriter?

  var micAudioResampler: AudioResampler?
  var micAudioTranscoder: RealtimeAudioTranscoder?
  var micAudioWriter: FragmentedAudioWriter?

  override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
    let width = 888
    let height = 1920
    let frameRate = 60
    let appSampleRate = 44_100
    let micSampleRate = 48_000
    let recordID = recoreonPathService.generateRecordID(date: .now)
    let outputDirectoryURL = recoreonPathService.generateAppGroupsFragmentedRecordURL(
      recordID: recordID)
    do {
      let videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

      let videoWriter = try FragmentedVideoWriter(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: "\(recordID)-video",
        frameRate: frameRate,
        sourceFormatHint: videoTranscoder.outputFormatDesc
      )

      self.videoTranscoder = videoTranscoder
      self.videoWriter = videoWriter

      let appAudioResampler = try AudioResampler(outputSampleRate: appSampleRate)

      let appAudioTranscoder = try RealtimeAudioTranscoder(
        inputAudioStreamBasicDesc: appAudioResampler.outputAudioStreamBasicDesc,
        outputSampleRate: appSampleRate
      )

      let appAudioTranscoderOutputFormatDesc = try CMFormatDescription(
        audioStreamBasicDescription: appAudioTranscoder.outputAudioStreamBasicDesc
      )
      let appAudioWriter = try FragmentedAudioWriter(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: "\(recordID)-app",
        sampleRate: appSampleRate,
        sourceFormatHint: appAudioTranscoderOutputFormatDesc
      )

      self.appAudioResampler = appAudioResampler
      self.appAudioTranscoder = appAudioTranscoder
      self.appAudioWriter = appAudioWriter

      let micAudioResampler = try AudioResampler(outputSampleRate: micSampleRate)

      let micAudioTranscoder = try RealtimeAudioTranscoder(
        inputAudioStreamBasicDesc: micAudioResampler.outputAudioStreamBasicDesc,
        outputSampleRate: appSampleRate
      )

      let micAudioTranscoderOutputFormatDesc = try CMFormatDescription(
        audioStreamBasicDescription: micAudioTranscoder.outputAudioStreamBasicDesc
      )
      let micAudioWriter = try FragmentedAudioWriter(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: "\(recordID)-mic",
        sampleRate: appSampleRate,
        sourceFormatHint: micAudioTranscoderOutputFormatDesc
      )

      self.micAudioResampler = micAudioResampler
      self.micAudioTranscoder = micAudioTranscoder
      self.micAudioWriter = micAudioWriter

      let masterPlaylistWriter = MasterPlaylistWriter()
      try masterPlaylistWriter.write(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: recordID,
        videoIndexURL: videoWriter.playlistURL,
        appAudioIndexURL: appAudioWriter.playlistURL,
        micAudioIndexURL: micAudioWriter.playlistURL
      )
    } catch {
      finishBroadcastWithError(error)
    }
  }

  override func broadcastPaused() {
    // User has requested to pause the broadcast. Samples will stop being delivered.
  }

  override func broadcastResumed() {
    // User has requested to resume the broadcast. Samples delivery will resume.
  }

  override func processSampleBuffer(
    _ sampleBuffer: CMSampleBuffer,
    with sampleBufferType: RPSampleBufferType
  ) {
    let ongoingRecordingTimestamp =
      appGroupsUserDefaults?.double(
        forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey
      ) ?? 0
    let now = Date().timeIntervalSince1970
    if now - ongoingRecordingTimestamp > 1 {
      appGroupsUserDefaults?.set(
        Date().timeIntervalSince1970,
        forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey
      )
    }

    guard let appAudioResampler = appAudioResampler,
      let appAudioTranscoder = appAudioTranscoder,
      let appAudioWriter = appAudioWriter,
      let micAudioResampler = micAudioResampler,
      let micAudioTranscoder = micAudioTranscoder,
      let micAudioWriter = micAudioWriter
    else {
      return
    }

    switch sampleBufferType {
    case RPSampleBufferType.video:
      processVideoSample(sampleBuffer)
    case RPSampleBufferType.audioApp:
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      guard let firstTime = screenFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: 44_100)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      do {
        try write(
          audioWriter: appAudioWriter,
          audioTranscoder: appAudioTranscoder,
          audioResampler: appAudioResampler,
          sampleBuffer: sampleBuffer,
          pts: elapsedTime
        )
      } catch {
        print(error)
      }
    case RPSampleBufferType.audioMic:
      let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
      if micFirstTime == nil {
        guard let elapsedTime = screenElapsedTime else { return }
        micFirstTime = CMTimeSubtract(pts, elapsedTime)
      }
      guard let firstTime = micFirstTime else { return }
      let elapsedTime = CMTimeSubtract(pts, firstTime)
      let elapsedCount = CMTimeMultiply(
        CMTimeSubtract(pts, firstTime), multiplier: 48_000)
      let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)

      do {
        try write(
          audioWriter: micAudioWriter,
          audioTranscoder: micAudioTranscoder,
          audioResampler: micAudioResampler,
          sampleBuffer: sampleBuffer,
          pts: elapsedTime
        )
      } catch {
        print(error)
      }
    @unknown default:
      fatalError("Unknown type of sample buffer")
    }
  }

  override func broadcastFinished() {
    let semaphore = DispatchSemaphore(value: 0)
    Task { [weak self] in
      guard let self = self else { return }
      self.videoTranscoder?.close()
      try await self.videoWriter?.close()
      try await self.appAudioWriter?.close()
      try await self.micAudioWriter?.close()
      semaphore.signal()
    }
    semaphore.wait()
  }

  func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    if !isOutputStarted {
      let width = CVPixelBufferGetWidth(pixelBuffer)
      let height = CVPixelBufferGetHeight(pixelBuffer)
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
    let elapsedCount = CMTimeMultiply(elapsedTime, multiplier: 60)
    let outputPTS = elapsedCount.value / Int64(elapsedCount.timescale)
    screenElapsedTime = elapsedTime

    videoTranscoder?.send(imageBuffer: pixelBuffer, pts: pts) {
      [weak self] (status, infoFlags, sbuf) in
      if let sampleBuffer = sbuf {
        try? self?.videoWriter?.send(sampleBuffer: sampleBuffer)
      }
    }
  }

  func write(
    audioWriter: FragmentedAudioWriter,
    audioTranscoder: RealtimeAudioTranscoder,
    audioResampler: AudioResampler,
    sampleBuffer: CMSampleBuffer,
    pts: CMTime
  ) throws {
    var blockBufferOut: CMBlockBuffer?
    var audioBufferList = AudioBufferList()
    CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
      sampleBuffer,
      bufferListSizeNeededOut: nil,
      bufferListOut: &audioBufferList,
      bufferListSize: MemoryLayout<AudioBufferList>.size,
      blockBufferAllocator: kCFAllocatorDefault,
      blockBufferMemoryAllocator: kCFAllocatorDefault,
      flags: 0,
      blockBufferOut: &blockBufferOut
    )

    guard
      let format = CMSampleBufferGetFormatDescription(sampleBuffer),
      let audioStreamBasicDesc = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee,
      audioStreamBasicDesc.mFormatID == kAudioFormatLinearPCM,
      let data = audioBufferList.mBuffers.mData
    else {
      print("err1")
      return
    }

    print(audioStreamBasicDesc)
    let isSignedInteger = audioStreamBasicDesc.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0
    let isMono = audioStreamBasicDesc.mChannelsPerFrame == 1
    let isStereo = audioStreamBasicDesc.mChannelsPerFrame == 2
    let bytesPerSample = Int(audioStreamBasicDesc.mBytesPerFrame) / (isStereo ? 2 : 1)
    let inputSampleRate = Int(audioStreamBasicDesc.mSampleRate)
    if isStereo && isSignedInteger && bytesPerSample == 2 {
      try audioResampler.append(
        stereoInt16Buffer: data.assumingMemoryBound(to: Int16.self),
        numSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 4,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else if isMono && isSignedInteger && bytesPerSample == 2 {
      try audioResampler.append(
        monoInt16Buffer: data.assumingMemoryBound(to: Int16.self),
        numSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 4,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else {
      print("Sample format is not supported!")
    }

    let audioResamplerFrame = audioResampler.getCurrentFrame()
    let audioTranscoderFrame = try audioTranscoder.send(
      inputBuffer: audioResamplerFrame.data,
      numInputSamples: audioResamplerFrame.numSamples
    )
    let packetDescs = Array(
      UnsafeBufferPointer(
        start: audioTranscoderFrame.packetDescs,
        count: audioTranscoderFrame.numPackets
      ))

    let buffer = UnsafeMutableRawBufferPointer(
      start: audioTranscoderFrame.audioBufferList.mBuffers.mData,
      count: Int(audioTranscoderFrame.audioBufferList.mBuffers.mDataByteSize)
    )
    let blockBuffer = try CMBlockBuffer(buffer: buffer, allocator: kCFAllocatorNull)
    let sampleBuffer = try CMSampleBuffer(
      dataBuffer: blockBuffer,
      formatDescription: audioTranscoder.outputFormatDesc,
      numSamples: audioTranscoderFrame.numPackets,
      presentationTimeStamp: pts,
      packetDescriptions: packetDescs
    )

    try audioWriter.send(sampleBuffer: sampleBuffer)
  }
}

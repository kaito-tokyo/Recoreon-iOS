import CoreMedia
import FragmentedRecordWriter
import RecoreonCommon
import ReplayKit
import Logging

enum SampleHandlerError: CustomNSError {
  case audioWriterRetrievalFailed

  var errorUserInfo: [String: Any] {
    switch self {
    case .audioWriterRetrievalFailed:
      return [
        NSLocalizedFailureReasonErrorKey: "Could not get audio writers!"
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

  let logger = Logger(label: "com.github.umireon.Recoreon.RecoreonBroadcastUploadExtension")
  let audioQueue = DispatchQueue(
    label: "com.github.umireon.Recoreon.RecoreonBroadcastUploadExtension.audioQueue"
  )

  var videoTranscoder: RealtimeVideoTranscoder?
  var videoWriter: FragmentedVideoWriter?

  var appAudioResampler: AudioResampler?
  var appAudioWriter: FragmentedAudioWriter?

  var micAudioResampler: AudioResampler?
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

      let appOutputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: appSampleRate,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 320_000
      ]
      let appAudioWriter = try FragmentedAudioWriter(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: "\(recordID)-app",
        outputSettings: appOutputSettings
      )

      self.appAudioResampler = appAudioResampler
      self.appAudioWriter = appAudioWriter

      let micAudioResampler = try AudioResampler(outputSampleRate: micSampleRate)


      let micOutputSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVSampleRateKey: micSampleRate,
        AVNumberOfChannelsKey: 2,
        AVEncoderBitRateKey: 320_000
      ]
      let micAudioWriter = try FragmentedAudioWriter(
        outputDirectoryURL: outputDirectoryURL,
        outputFilePrefix: "\(recordID)-mic",
        outputSettings: micOutputSettings
      )

      self.micAudioResampler = micAudioResampler
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
      let appAudioWriter = appAudioWriter,
      let micAudioResampler = micAudioResampler,
      let micAudioWriter = micAudioWriter
    else {
      finishBroadcastWithError(SampleHandlerError.audioWriterRetrievalFailed)
      return
    }

    switch sampleBufferType {
    case RPSampleBufferType.video:
      processVideoSample(sampleBuffer)
    case RPSampleBufferType.audioApp:
      audioQueue.async { [weak self] in
        do {
          try self?.write(
            audioWriter: appAudioWriter,
            audioResampler: appAudioResampler,
            sampleBuffer: sampleBuffer,
            pts: sampleBuffer.presentationTimeStamp
          )
        } catch {
          print(error)
        }
      }
    case RPSampleBufferType.audioMic:
      audioQueue.async { [weak self] in
        do {
          try self?.write(
            audioWriter: micAudioWriter,
            audioResampler: micAudioResampler,
            sampleBuffer: sampleBuffer,
            pts: sampleBuffer.presentationTimeStamp
          )
        } catch {
          print(error)
        }
      }
    @unknown default:
      fatalError("Unknown type of sample buffer")
    }
  }

  override func broadcastFinished() {
    let semaphore = DispatchSemaphore(value: 0)
    Task { [weak self] in
      guard let self = self else {
        print("Clean up failed!")
        return
      }
      self.videoTranscoder?.close()
      try await self.videoWriter?.close()
      try await self.appAudioWriter?.close()
      try await self.micAudioWriter?.close()
      semaphore.signal()
    }
    semaphore.wait()
  }

  func processVideoSample(_ sampleBuffer: CMSampleBuffer) {
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      logger.warning("Video sample buffer is not available!")
      return
    }

    if !isOutputStarted {
      isOutputStarted = true
    }

    if screenStartupCount > 0 {
      let value = screenStartupCount % screenStartupThrottlingFactor
      screenStartupCount -= 1
      if value > 0 {
        return
      }
    }

    let pts = CMTimeConvertScale(
      sampleBuffer.presentationTimeStamp,
      timescale: 60,
      method: .roundTowardPositiveInfinity
    )

    videoTranscoder?.send(imageBuffer: pixelBuffer, pts: pts) {
      [weak self] (status, infoFlags, sbuf) in
      if let sampleBuffer = sbuf {
        try? self?.videoWriter?.send(sampleBuffer: sampleBuffer)
      }
    }
  }

  func write(
    audioWriter: FragmentedAudioWriter,
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
      logger.error("Audio input sample could not be gotten!")
      return
    }

    let isSignedInteger = audioStreamBasicDesc.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0
    let isMono = audioStreamBasicDesc.mChannelsPerFrame == 1
    let isStereo = audioStreamBasicDesc.mChannelsPerFrame == 2
    let isBigEndian = audioStreamBasicDesc.mFormatFlags & kAudioFormatFlagIsBigEndian != 0
    let bytesPerSample = Int(audioStreamBasicDesc.mBytesPerFrame) / (isStereo ? 2 : 1)
    let inputSampleRate = Int(audioStreamBasicDesc.mSampleRate)
    if isStereo && isSignedInteger && bytesPerSample == 2 && !isBigEndian {
      try audioResampler.append(
        stereoInt16Buffer: data.assumingMemoryBound(to: Int16.self),
        numInputSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 4,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else if isMono && isSignedInteger && bytesPerSample == 2 && !isBigEndian {
      try audioResampler.append(
        monoInt16Buffer: data.assumingMemoryBound(to: Int16.self),
        numInputSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 2,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else if isStereo && isSignedInteger && bytesPerSample == 2 && isBigEndian {
      try audioResampler.append(
        stereoInt16BufferWithSwap: data.assumingMemoryBound(to: Int16.self),
        numInputSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 4,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else if isMono && isSignedInteger && bytesPerSample == 2 && isBigEndian {
      try audioResampler.append(
        monoInt16BufferWithSwap: data.assumingMemoryBound(to: Int16.self),
        numInputSamples: Int(audioBufferList.mBuffers.mDataByteSize) / 2,
        inputSampleRate: inputSampleRate,
        pts: pts
      )
    } else {
      logger.warning("Audio sample format is not supported!")
    }

    let audioResamplerFrame = audioResampler.getCurrentFrame()

    let buffer = UnsafeMutableRawBufferPointer(audioResamplerFrame.data)
    let blockBuffer = try CMBlockBuffer(buffer: buffer, allocator: kCFAllocatorNull)

    let sampleTiming = CMSampleTimingInfo(
      duration: audioResampler.duration,
      presentationTimeStamp: pts,
      decodeTimeStamp: .invalid
    )

    let samplerBuffer = try CMSampleBuffer(
      dataBuffer: blockBuffer,
      formatDescription: audioResampler.outputFormatDesc,
      numSamples: audioResamplerFrame.numSamples,
      sampleTimings: [sampleTiming],
      sampleSizes: []
    )

    try audioWriter.send(sampleBuffer: sampleBuffer)
  }
}

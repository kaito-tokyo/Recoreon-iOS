import AVFoundation
import CoreMedia
import Foundation

public class FragmentedMP4Writer {
  private let assetWriter: AVAssetWriter

  private let frameRate: CMTimeScale = 60
  private let appAudioSampleRate: CMTimeScale = 44100
  private let micAudioSampleRate: CMTimeScale = 48000

  private let videoInput: AVAssetWriterInput
  private let appAudioInput: AVAssetWriterInput
  private let micAudioInput: AVAssetWriterInput

  private var sessionStarted = false

  public init(outputURL: URL, width: Int, height: Int) throws {
    assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    assetWriter.movieTimeScale = frameRate

    let videoFormatDesc = try CMFormatDescription(
      videoCodecType: .h264, width: width, height: height)
    videoInput = AVAssetWriterInput(
      mediaType: .video, outputSettings: nil, sourceFormatHint: videoFormatDesc)
    videoInput.expectsMediaDataInRealTime = true

    appAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    appAudioInput.expectsMediaDataInRealTime = true

    micAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: nil)
    micAudioInput.expectsMediaDataInRealTime = true

    assetWriter.add(videoInput)
    assetWriter.add(appAudioInput)
    assetWriter.add(micAudioInput)

    guard assetWriter.startWriting() else {
      throw assetWriter.error!
    }

  }

  func sendVideoSampleBuffer(sampleBuffer: CMSampleBuffer) throws {
    let rescaledPTS = CMTimeConvertScale(
      sampleBuffer.presentationTimeStamp, timescale: frameRate,
      method: .roundTowardPositiveInfinity)

    if !sessionStarted {
      assetWriter.startSession(atSourceTime: rescaledPTS)
      sessionStarted = true
    }

    if videoInput.isReadyForMoreMediaData {
      try sampleBuffer.setOutputPresentationTimeStamp(rescaledPTS)
      videoInput.append(sampleBuffer)
    } else {
      print(
        String(
          format: "Error: VideoSink dropped a frame [PTS: %.3f]",
          sampleBuffer.presentationTimeStamp.seconds
        ))
    }
  }

  func sendAppAudioSampleBuffer(sampleBuffer: CMSampleBuffer) throws {
    guard sessionStarted else { return }

    if appAudioInput.isReadyForMoreMediaData {
      let rescaledPTS = CMTimeConvertScale(
        sampleBuffer.presentationTimeStamp, timescale: appAudioSampleRate,
        method: .roundTowardPositiveInfinity)
      try sampleBuffer.setOutputPresentationTimeStamp(rescaledPTS)

      appAudioInput.append(sampleBuffer)
    }
  }

  func sendMicAudioSampleBuffer(sampleBuffer: CMSampleBuffer) throws {
    guard sessionStarted else { return }

    if micAudioInput.isReadyForMoreMediaData {
      let rescaledPTS = CMTimeConvertScale(
        sampleBuffer.presentationTimeStamp, timescale: micAudioSampleRate,
        method: .roundTowardPositiveInfinity)
      try sampleBuffer.setOutputPresentationTimeStamp(rescaledPTS)

      micAudioInput.append(sampleBuffer)
    }
  }

  func close() async throws {
    videoInput.markAsFinished()
    appAudioInput.markAsFinished()
    micAudioInput.markAsFinished()

    await assetWriter.finishWriting()
    if assetWriter.status == .failed {
      throw assetWriter.error!
    }
  }
}

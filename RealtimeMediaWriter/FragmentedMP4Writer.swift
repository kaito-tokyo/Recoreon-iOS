import AVFoundation
import CoreMedia
import Foundation

public class FragmentedMP4Writer {
  private let frameRate: CMTimeScale

  private let assetWriter: AVAssetWriter
  private let videoInput: AVAssetWriterInput

  private var sessionStarted = false

  public init(outputURL: URL, frameRate: Int, videoFormatDesc: CMFormatDescription) throws {
    self.frameRate = CMTimeScale(frameRate)

    assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
    assetWriter.movieTimeScale = self.frameRate

    videoInput = AVAssetWriterInput(
      mediaType: .video, outputSettings: nil, sourceFormatHint: videoFormatDesc)
    videoInput.expectsMediaDataInRealTime = true

    assetWriter.add(videoInput)

    guard assetWriter.startWriting() else {
      throw assetWriter.error!
    }
  }

  public func sendVideoSampleBuffer(sampleBuffer: CMSampleBuffer) throws {
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

  public func close() async throws {
    videoInput.markAsFinished()

    await assetWriter.finishWriting()
    if assetWriter.status == .failed {
      throw assetWriter.error!
    }
  }
}

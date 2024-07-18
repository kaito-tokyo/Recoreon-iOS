import AVFoundation
import CoreMedia
import Foundation

enum FragmentedMP4WriterError: CustomNSError {
  case outputMP4OpeningFailure
}

struct SeparableSegment {
  let filename: String
  let earliestPTS: CMTime
  let duration: CMTime
}

private class FragmentedMP4WriterDelegate: NSObject, AVAssetWriterDelegate {
  private let outputDirectoryURL: URL
  private let outputFilePrefix: String

  private var segmentIndex = 0
  private(set) var initializationSegmentFilename: String?
  private(set) var separableSegments: [SeparableSegment] = []

  init(outputDirectoryURL: URL, outputFilePrefix: String) throws {
    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    super.init()
  }

  func assetWriter(
    _ writer: AVAssetWriter, didOutputSegmentData segmentData: Data,
    segmentType: AVAssetSegmentType, segmentReport: AVAssetSegmentReport?
  ) {
    let outputURL: URL

    switch segmentType {
    case .initialization:
      let filename = "\(outputFilePrefix)-init.m4s"
      outputURL = outputDirectoryURL.appending(path: filename)
      initializationSegmentFilename = filename
    case .separable:
      let paddedSegmentIndex = String(format: "%06d", segmentIndex)
      let filename = "\(outputFilePrefix)-\(paddedSegmentIndex).m4s"
      outputURL = outputDirectoryURL.appending(path: filename)

      let timingTrackInfo = segmentReport!.trackReports.first(where: { $0.mediaType == .video })!
      let earliestPTS = timingTrackInfo.earliestPresentationTimeStamp
      let duration = timingTrackInfo.duration
      separableSegments.append(
        SeparableSegment(filename: filename, earliestPTS: earliestPTS, duration: duration))

      segmentIndex += 1
    @unknown default:
      print("Skipping segment with unrecognized type \(segmentType)")
      return
    }
    try? segmentData.write(to: outputURL)
  }
}

public class FragmentedMP4Writer {
  private let outputDirectoryURL: URL
  private let outputFilePrefix: String
  private let frameRate: CMTimeScale

  private let assetWriter: AVAssetWriter
  private let delegate: FragmentedMP4WriterDelegate
  private let videoInput: AVAssetWriterInput
  private let appAudioInput: AVAssetWriterInput

  private var sessionStarted = false

  public init(
    outputDirectoryURL: URL, outputFilePrefix: String, frameRate: Int,
    videoOutputSettings: [String: Any], appAudioOutputSettings: [String: Any]
  ) throws {
    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    self.frameRate = CMTimeScale(frameRate)

    assetWriter = AVAssetWriter(contentType: .mpeg4Movie)
    assetWriter.movieTimeScale = self.frameRate
    assetWriter.outputFileTypeProfile = .mpeg4AppleHLS
    assetWriter.preferredOutputSegmentInterval = CMTime(seconds: 6, preferredTimescale: 1)
    assetWriter.initialSegmentStartTime = CMTime.zero

    delegate = try FragmentedMP4WriterDelegate(
      outputDirectoryURL: outputDirectoryURL, outputFilePrefix: outputFilePrefix)
    assetWriter.delegate = delegate

    videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
    videoInput.expectsMediaDataInRealTime = true

    appAudioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: appAudioOutputSettings)
    appAudioInput.expectsMediaDataInRealTime = true

    assetWriter.add(videoInput)
    assetWriter.add(appAudioInput)

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

  public func sendAppAudio(sampleBuffer: CMSampleBuffer) throws {
    guard sessionStarted else { return }

    if appAudioInput.isReadyForMoreMediaData {
      appAudioInput.append(sampleBuffer)
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
    appAudioInput.markAsFinished()

    await assetWriter.finishWriting()
    if assetWriter.status == .failed {
      throw assetWriter.error!
    }

    let outputIndexURL = outputDirectoryURL.appending(
      path: "\(outputFilePrefix).m3u8", directoryHint: .notDirectory)

    guard let initializationSegmentFilename = delegate.initializationSegmentFilename else {
      return
    }

    let indexHeader = """
      #EXTM3U
      #EXT-X-TARGETDURATION:6
      #EXT-X-VERSION:7
      #EXT-X-MEDIA-SEQUENCE:1
      #EXT-X-PLAYLIST-TYPE:VOD
      #EXT-X-INDEPENDENT-SEGMENTS
      #EXT-X-MAP:URI="\(initializationSegmentFilename)"
      """

    let separableSegments = delegate.separableSegments
    let indexComponents = zip(
      separableSegments, separableSegments.dropFirst()
    ).map { (first, second) in
      let segmentDuration = second.earliestPTS - first.earliestPTS
      return """
        #EXTINF:\(String(format: "%1.5f", segmentDuration.seconds)),
        \(first.filename)
        """
    }

    let lastSeparableSegment = separableSegments.last!
    let segmentDuration = lastSeparableSegment.duration
    let indexFooter = """
      #EXTINF:\(String(format: "%1.5f", segmentDuration.seconds)),
      \(lastSeparableSegment.filename)
      #EXT-X-ENDLIST
      """

    let indexContent = "\(indexHeader)\n\(indexComponents.joined(separator: "\n"))\n\(indexFooter)"
    try indexContent.write(to: outputIndexURL, atomically: true, encoding: .utf8)
  }
}

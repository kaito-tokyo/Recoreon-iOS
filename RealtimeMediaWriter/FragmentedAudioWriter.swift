import AVFoundation
import CoreMedia
import Foundation

enum FragmentedAudioWriterError: CustomNSError {
  case notImplementedError
}

struct SeparableAudioSegment {
  let filename: String
  let earliestPTS: CMTime
  let duration: CMTime
}

private class FragmentedAudioWriterDelegate: NSObject, AVAssetWriterDelegate {
  private let outputDirectoryURL: URL
  private let outputFilePrefix: String

  private var segmentIndex = 0
  private(set) var initializationSegmentFilename: String?
  private(set) var separableSegments: [SeparableAudioSegment] = []

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

      let timingTrackInfo = segmentReport!.trackReports[0]
      let earliestPTS = timingTrackInfo.earliestPresentationTimeStamp
      let duration = timingTrackInfo.duration
      separableSegments.append(
        SeparableAudioSegment(filename: filename, earliestPTS: earliestPTS, duration: duration))

      segmentIndex += 1
    @unknown default:
      print("Skipping segment with unrecognized type \(segmentType)")
      return
    }
    try? segmentData.write(to: outputURL)
  }
}

public class FragmentedAudioWriter {
  private let outputDirectoryURL: URL
  private let outputFilePrefix: String
  private let sampleRate: Int

  private let assetWriter: AVAssetWriter
  private let delegate: FragmentedAudioWriterDelegate
  private let audioInput: AVAssetWriterInput

  private var sessionStarted = false

  public init(
    outputDirectoryURL: URL,
    outputFilePrefix: String,
    sampleRate: Int,
    sourceFormatHint: CMFormatDescription
  ) throws {
    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    self.sampleRate = sampleRate

    assetWriter = AVAssetWriter(contentType: .mpeg4Movie)
    assetWriter.outputFileTypeProfile = .mpeg4AppleHLS
    assetWriter.preferredOutputSegmentInterval = CMTime(seconds: 6, preferredTimescale: 1)
    assetWriter.initialSegmentStartTime = CMTime.zero

    delegate = try FragmentedAudioWriterDelegate(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: outputFilePrefix
    )
    assetWriter.delegate = delegate

    let audioOutputSettings: [String: Any] = [
      AVFormatIDKey: kAudioFormatMPEG4AAC,
      AVSampleRateKey: 48_000,
      AVNumberOfChannelsKey: 2,
      AVEncoderBitRateKey: 320_000,
    ]
    audioInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: audioOutputSettings,
      sourceFormatHint: sourceFormatHint
    )
    audioInput.expectsMediaDataInRealTime = true

    assetWriter.add(audioInput)

    guard assetWriter.startWriting() else {
      throw assetWriter.error!
    }
  }

  public func send(sampleBuffer: CMSampleBuffer) throws {
    let rescaledPTS = CMTimeConvertScale(
      sampleBuffer.presentationTimeStamp,
      timescale: CMTimeScale(sampleRate),
      method: .roundTowardPositiveInfinity
    )

    if !sessionStarted {
      assetWriter.startSession(atSourceTime: rescaledPTS)
      sessionStarted = true
    }

    if audioInput.isReadyForMoreMediaData {
      audioInput.append(sampleBuffer)
    } else {
      print(
        String(
          format: "Error: AudioSink dropped a frame [PTS: %.3f]",
          sampleBuffer.presentationTimeStamp.seconds
        ))
    }
  }

  public func close() async throws {
    audioInput.markAsFinished()

    await assetWriter.finishWriting()
    if assetWriter.status == .failed {
      throw assetWriter.error!
    }
  }

  public func writeIndexPlaylist() throws -> URL {
    let outputIndexURL = outputDirectoryURL.appending(
      path: "\(outputFilePrefix).m3u8",
      directoryHint: .notDirectory
    )

    guard let initializationSegmentFilename = delegate.initializationSegmentFilename else {
      throw FragmentedAudioWriterError.notImplementedError
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

    let indexContent = """
      \(indexHeader)
      \(indexComponents.joined(separator: "\n"))
      \(indexFooter)
      """
    try indexContent.write(to: outputIndexURL, atomically: true, encoding: .utf8)

    return outputIndexURL
  }
}

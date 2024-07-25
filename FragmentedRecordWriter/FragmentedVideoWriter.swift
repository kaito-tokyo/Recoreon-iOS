import AVFoundation
import CoreMedia
import Foundation

enum FragmentedVideoWriterError: CustomNSError {
}

private class FragmentedVideoWriterDelegate: NSObject, AVAssetWriterDelegate {
  var firstVideoFrameArrivalTime = Date(timeIntervalSince1970: 0)
  var startPTS: CMTime = .invalid

  public let playlistURL: URL

  private let outputDirectoryURL: URL
  private let outputFilePrefix: String
  private let dateTimeFormatter: ISO8601DateFormatter

  private var segmentIndex = 0
  private var lastSeparableSegmentReport: AVAssetSegmentReport?
  private var lastSeparableSegmentURL: URL?

  init(outputDirectoryURL: URL, outputFilePrefix: String) throws {
    playlistURL = outputDirectoryURL.appending(
      path: "\(outputFilePrefix).m3u8",
      directoryHint: .notDirectory
    )

    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    dateTimeFormatter = ISO8601DateFormatter()
    dateTimeFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    super.init()

    let playlistHeader = """
      #EXTM3U
      #EXT-X-TARGETDURATION:6
      #EXT-X-VERSION:7
      #EXT-X-MEDIA-SEQUENCE:1
      #EXT-X-PLAYLIST-TYPE:VOD
      #EXT-X-INDEPENDENT-SEGMENTS\n
      """
    writeToPlaylist(content: playlistHeader, append: false)
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

      let playlistContent = """
        #EXT-X-MAP:URI="\(filename)"\n
        """
      writeToPlaylist(content: playlistContent, append: true)
    case .separable:
      let paddedSegmentIndex = String(format: "%06d", segmentIndex)
      let filename = "\(outputFilePrefix)-\(paddedSegmentIndex).m4s"
      outputURL = outputDirectoryURL.appending(path: filename)

      if let lastEarliestPTS = lastSeparableSegmentReport?.trackReports.first?
        .earliestPresentationTimeStamp,
        let earliestPTS = segmentReport?.trackReports.first?.earliestPresentationTimeStamp,
        let lastSeparableSegmentURL = lastSeparableSegmentURL
      {
        let lastSegmentDuration = earliestPTS - lastEarliestPTS
        let playlistContent = """
          #EXT-X-PROGRAM-DATE-TIME:\(getProgramDateTime(pts: lastEarliestPTS))
          #EXTINF:\(String(format: "%1.5f", lastSegmentDuration.seconds)),
          \(lastSeparableSegmentURL.lastPathComponent)\n
          """
        writeToPlaylist(content: playlistContent, append: true)
      }

      lastSeparableSegmentReport = segmentReport
      lastSeparableSegmentURL = outputURL

      segmentIndex += 1
    @unknown default:
      print("Skipping segment with unrecognized type \(segmentType)")
      return
    }
    try? segmentData.write(to: outputURL)
  }

  func close() {
    if let lastDuration = lastSeparableSegmentReport?.trackReports.first?.duration,
      let lastSeparableSegmentURL = lastSeparableSegmentURL
    {
      let playlistContent = """
        #EXTINF:\(String(format: "%1.5f", lastDuration.seconds)),
        \(lastSeparableSegmentURL.lastPathComponent)\n
        """
      writeToPlaylist(content: playlistContent, append: true)
    }
    writeToPlaylist(content: "#EXT-X-ENDLIST\n", append: true)
  }

  private func getProgramDateTime(pts: CMTime) -> String {
    let elapsedTime = pts - startPTS
    let targetDate = (firstVideoFrameArrivalTime + elapsedTime.seconds)
    return dateTimeFormatter.string(from: targetDate)
  }

  private func writeToPlaylist(content: String, append: Bool) {
    guard let outputStream = OutputStream(url: playlistURL, append: append) else {
      return
    }
    outputStream.open()
    defer {
      outputStream.close()
    }

    var content = content
    content.withUTF8 { bytes in
      if let buffer = bytes.baseAddress {
        outputStream.write(buffer, maxLength: bytes.count)
      }
    }
  }
}

public class FragmentedVideoWriter {
  public var firstVideoFrameArrivalTime: Date {
    get { delegate.firstVideoFrameArrivalTime }
    set(value) { delegate.firstVideoFrameArrivalTime = value }
  }

  public var playlistURL: URL {
    delegate.playlistURL
  }

  private let outputDirectoryURL: URL
  private let outputFilePrefix: String
  private let frameRate: CMTimeScale

  private let assetWriter: AVAssetWriter
  private let delegate: FragmentedVideoWriterDelegate
  private let videoInput: AVAssetWriterInput

  private var sessionStarted = false
  private var startPTS: CMTime = .invalid

  public init(
    outputDirectoryURL: URL,
    outputFilePrefix: String,
    frameRate: Int,
    sourceFormatHint: CMFormatDescription
  ) throws {
    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    self.frameRate = CMTimeScale(frameRate)

    assetWriter = AVAssetWriter(contentType: .mpeg4Movie)
    assetWriter.movieTimeScale = self.frameRate
    assetWriter.outputFileTypeProfile = .mpeg4CMAFCompliant
    assetWriter.preferredOutputSegmentInterval = CMTime(seconds: 6, preferredTimescale: 1)
    assetWriter.initialSegmentStartTime = CMTime.zero

    delegate = try FragmentedVideoWriterDelegate(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: outputFilePrefix
    )
    assetWriter.delegate = delegate

    videoInput = AVAssetWriterInput(
      mediaType: .video, outputSettings: nil, sourceFormatHint: sourceFormatHint)
    videoInput.expectsMediaDataInRealTime = true

    assetWriter.add(videoInput)

    guard assetWriter.startWriting() else {
      throw assetWriter.error!
    }
  }

  public func send(sampleBuffer: CMSampleBuffer) throws {
    let rescaledPTS = CMTimeConvertScale(
      sampleBuffer.presentationTimeStamp,
      timescale: frameRate,
      method: .roundTowardPositiveInfinity
    )

    if !sessionStarted {
      assetWriter.startSession(atSourceTime: rescaledPTS)
      delegate.startPTS = rescaledPTS
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

    delegate.close()
  }
}

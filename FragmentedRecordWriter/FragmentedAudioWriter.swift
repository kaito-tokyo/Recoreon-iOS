import AVFoundation
import CoreMedia
import Foundation

enum FragmentedAudioWriterError: CustomNSError {
  case notImplementedError
}

private class FragmentedAudioWriterDelegate: NSObject, AVAssetWriterDelegate {
  public let playlistURL: URL

  private let outputDirectoryURL: URL
  private let outputFilePrefix: String

  private var segmentIndex = 0

  init(outputDirectoryURL: URL, outputFilePrefix: String) throws {
    playlistURL = outputDirectoryURL.appending(
      path: "\(outputFilePrefix).m3u8",
      directoryHint: .notDirectory
    )

    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix
    super.init()

    let playlistHeader =  """
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
      let filename = "\(outputFilePrefix)-\(String(format: "%06d", segmentIndex)).m4s"
      outputURL = outputDirectoryURL.appending(path: filename)

      if let segmentDuration = segmentReport?.trackReports.first?.duration {
        let playlistContent = """
            #EXTINF:\(String(format: "%1.5f", segmentDuration.seconds)),
            \(outputURL.lastPathComponent)\n
            """
        writeToPlaylist(content: playlistContent, append: true)
      }

      segmentIndex += 1
    @unknown default:
      print("Skipping segment with unrecognized type \(segmentType)")
      return
    }
    try? segmentData.write(to: outputURL)
  }

  func close() {
    writeToPlaylist(content: "#EXT-X-ENDLIST\n", append: true)
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

    audioInput = AVAssetWriterInput(
      mediaType: .audio,
      outputSettings: nil,
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

    delegate.close()
  }
}

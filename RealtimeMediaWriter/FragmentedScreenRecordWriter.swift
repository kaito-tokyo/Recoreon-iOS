import Foundation
import CoreMedia

public struct FragmentedScreenRecordWriter {
  private let outputDirectoryURL: URL
  private let outputFilePrefix: String

  private let videoWriter: FragmentedVideoWriter
  private let videoTranscoder: RealtimeVideoTranscoder

  private let appAudioWriter: FragmentedAudioWriter
  private let micAudioWriter: FragmentedAudioWriter


  public init(
    outputDirectoryURL: URL,
    outputFilePrefix: String,
    width: Int,
    height: Int,
    frameRate: Int
  ) throws {
    self.outputDirectoryURL = outputDirectoryURL
    self.outputFilePrefix = outputFilePrefix

    videoWriter = try FragmentedVideoWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: "\(outputFilePrefix)-video",
      frameRate: 60,
      sourceFormatHint: CMFormatDescription(
        videoCodecType: .h264,
        width: width,
        height: height
      )
    )

    videoTranscoder = try RealtimeVideoTranscoder(width: width, height: height)

    appAudioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: "\(outputFilePrefix)-app",
      sampleRate: 44_100,
      sourceFormatHint: CMFormatDescription(audioStreamBasicDescription: AudioStreamBasicDescription(
        mSampleRate: 44_100,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0
      ))
    )

    micAudioWriter = try FragmentedAudioWriter(
      outputDirectoryURL: outputDirectoryURL,
      outputFilePrefix: "\(outputFilePrefix)-mic",
      sampleRate: 44_100,
      sourceFormatHint: CMFormatDescription(audioStreamBasicDescription: AudioStreamBasicDescription(
        mSampleRate: 44_100,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: 4,
        mFramesPerPacket: 1,
        mBytesPerFrame: 4,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 16,
        mReserved: 0
      ))
    )
  }

  public func sendVideo(imageBuffer: CVImageBuffer, pts: CMTime) throws {
    videoTranscoder.send(imageBuffer: imageBuffer, pts: pts) { (status, _, sbuf) in
      guard status == noErr, let sampleBuffer = sbuf else {
        return
      }
      try? videoWriter.send(sampleBuffer: sampleBuffer)
    }
  }

  public func sendAppAudio(sampleBuffer: CMSampleBuffer) throws {
    try appAudioWriter.send(sampleBuffer: sampleBuffer)
  }

  public func sendMicAudio(sampleBuffer: CMSampleBuffer) throws {
    try micAudioWriter.send(sampleBuffer: sampleBuffer)
  }

  public func close() async throws {
    try await videoWriter.close()
    try await appAudioWriter.close()
    try await micAudioWriter.close()
  }

  public func writeMasterPlaylist() throws {
    let videoIndexURL = try videoWriter.writeIndexPlaylist()
    let appAudioIndexURL = try appAudioWriter.writeIndexPlaylist()
    let micAudioIndexURL = try micAudioWriter.writeIndexPlaylist()

    let masterPlaylistURL = outputDirectoryURL.appending(path: "\(outputFilePrefix).m3u8")
    let masterPlaylistContent = """
      #EXTM3U
      #EXT-X-STREAM-INF:BANDWIDTH=150000,CODECS="avc1.42e00a,mp4a.40.2",AUDIO="audio"
      \(videoIndexURL.lastPathComponent)

      #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="App",DEFAULT=YES,URI="\(appAudioIndexURL.lastPathComponent)"
      #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="audio",NAME="Mic",DEFAULT=NO,URI="\(micAudioIndexURL.lastPathComponent)"
      """

    try masterPlaylistContent.write(to: masterPlaylistURL, atomically: true, encoding: .utf8)
  }
}

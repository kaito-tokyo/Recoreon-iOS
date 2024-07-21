//
//  MasterPlaylistWriter.swift
//  FragmentedRecordWriter
//
//  Created by Kaito Udagawa on 2024/07/21.
//

import Foundation

public struct MasterPlaylistWriter {

  public init() {
  }

  public func write(
    outputDirectoryURL: URL,
    outputFilePrefix: String,
    videoIndexURL: URL,
    appAudioIndexURL: URL,
    micAudioIndexURL: URL
  ) throws {
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

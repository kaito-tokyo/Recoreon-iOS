import AVFoundation
import CoreAudio
import Foundation
import FragmentedRecordWriter
import XCTest

private let appSampleRate = 44_100
private let height = 1920
private let frameRate = 60
private let documentsURL = FileManager.default.urls(
    for: .documentDirectory,
    in: .userDomainMask
)[0]

final class FragmentedAudioWriterTests: XCTestCase {
    func testCreateAppAudioStream() async throws {
        let sampleRate = appSampleRate
        let name = "FragmentedAudioWriterTests_testCreateAppAudioStream"
        let outputDirectoryURL = documentsURL.appending(
            path: name,
            directoryHint: .isDirectory
        )
        try? FileManager.default.removeItem(at: outputDirectoryURL)
        try FileManager.default.createDirectory(
            at: outputDirectoryURL,
            withIntermediateDirectories: true
        )

        print("Output directory is \(outputDirectoryURL.path())")

        let inputAudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger
                | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4,
            mFramesPerPacket: 1,
            mBytesPerFrame: 4,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        let outputAudioStreamBasicDescription = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate),
            mFormatID: kAudioFormatMPEG4AAC,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: 1024,
            mBytesPerFrame: 0,
            mChannelsPerFrame: 2,
            mBitsPerChannel: 0,
            mReserved: 0
        )

        let outputFormatDesc = try CMFormatDescription(
            audioStreamBasicDescription: outputAudioStreamBasicDescription
        )

        let dummyAppAudioGenerator = try DummyAudioGenerator(
            sampleRate: sampleRate,
            numChannels: 2,
            bytesPerSample: 2,
            isSwapped: false,
            initialPTS: .zero
        )

        let appOutputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: Float64(sampleRate),
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 320_000,
        ]
        let audioWriter = try FragmentedAudioWriter(
            outputDirectoryURL: outputDirectoryURL,
            outputFilePrefix: "\(name)-app",
            outputSettings: appOutputSettings,
        )

        for _ in 0..<sampleRate * 10 / 1024 {
            let audioFrame = dummyAppAudioGenerator.generateNextAudioFrame()

            var audioBufferList = audioFrame.audioBufferList

            let sampleTiming = CMSampleTimingInfo(
                duration: CMTime(value: 1, timescale: CMTimeScale(sampleRate)),
                presentationTimeStamp: audioFrame.pts,
                decodeTimeStamp: .invalid,
            )

            var sampleBufferOut: CMSampleBuffer?
            let err1 = CMAudioSampleBufferCreateWithPacketDescriptions(
                allocator: nil,
                dataBuffer: nil,
                dataReady: false,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: outputFormatDesc,
                sampleCount: Int(audioBufferList.mNumberBuffers),
                presentationTimeStamp: audioFrame.pts,
                packetDescriptions: nil,
                sampleBufferOut: &sampleBufferOut
            )

            guard err1 == noErr, let sampleBuffer = sampleBufferOut else {
                XCTFail("Could not create CMSampleBuffer for AudioBufferList!")
                return
            }

            let err2 = CMSampleBufferSetDataBufferFromAudioBufferList(
                sampleBuffer,
                blockBufferAllocator: kCFAllocatorDefault,
                blockBufferMemoryAllocator: kCFAllocatorDefault,
                flags: 0,
                bufferList: &audioBufferList
            )
            guard err2 == noErr else {
                XCTFail("Could not load AudioBufferList to CMSampleBuffer!")
                return
            }

            try audioWriter.send(sampleBuffer: sampleBuffer)

            try await Task.sleep(
                nanoseconds: UInt64(1_000_000_000 / sampleRate)
            )
        }

        try await audioWriter.close()
    }
}

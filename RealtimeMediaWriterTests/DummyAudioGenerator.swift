import Foundation
import CoreAudio
import CoreMedia

struct AudioFrame {
  let audioBufferList: AudioBufferList
  let pts: CMTime
}

class DummyAudioGenerator {
  private let sampleRate: Int
  private let initialPTS: CMTime

  private var state: DummyAudioGeneratorState
  private var sampleIndex = 0

  private let numSamples = 1024
  private let numChannels = 2
  private let dataByteSize = 4096

  init(sampleRate: Int, initialPTS: CMTime) {
    self.sampleRate = sampleRate
    self.initialPTS = initialPTS
  
    self.state = DummyAudioGeneratorState(
      data: .allocate(capacity: numSamples * numChannels),
      numSamples: numSamples,
      numChannels: numChannels,
      t: 0,
      tincr: 2 * Double.pi * 330.0 / Double(sampleRate),
      tincr2:  2 * Double.pi * 330.0 / Double(sampleRate) / Double(sampleRate)
    )
  }

  func generateNextAudioFrame() -> AudioFrame {
    let ab = AudioBuffer(mNumberChannels: UInt32(numChannels), mDataByteSize: UInt32(dataByteSize), mData: state.data)
    let abl = AudioBufferList(mNumberBuffers: 1, mBuffers: ab)
    fillAudio(&state)

    let elapsedTime = CMTime(value: CMTimeValue(sampleIndex), timescale: CMTimeScale(sampleRate))
    let pts = CMTimeAdd(initialPTS, elapsedTime)

    sampleIndex += numSamples

    return AudioFrame(
      audioBufferList: abl,
      pts: pts
    )
  }
}

import CoreAudio

class SameRateAudioResampler {
  let destNumSamples: Int

  init(destNumSamples: Int) {
    self.destNumSamples = destNumSamples
  }

  func copyStereoToStereo(
    fromData: UnsafeRawPointer, toData: UnsafeMutableRawPointer, numSamples: Int,
    handler: () -> Void
  ) {
    toData.copyMemory(from: fromData, byteCount: numSamples * 4)
    handler()
  }

  func copyStereoToStereoWithSwap(
    fromData: UnsafeRawPointer, toData: UnsafeMutableRawPointer, numSamples: Int,
    handler: () -> Void
  ) {
    let fromView = fromData.assumingMemoryBound(to: UInt16.self)
    let toView = toData.assumingMemoryBound(to: UInt16.self)
    for index in 0..<numSamples * 2 {
      let value = CFSwapInt16BigToHost(fromView[index])
      toView[index] = value
    }
    handler()
  }

  func copyMonoToStereo(
    fromData: UnsafeRawPointer, toData: UnsafeMutableRawPointer, numSamples: Int,
    handler: () -> Void
  ) {
    var offsetNumSamples = 0
    while offsetNumSamples < numSamples {
      let fromView = fromData.advanced(by: offsetNumSamples * 2).assumingMemoryBound(
        to: UInt16.self)
      let toView = toData.advanced(by: offsetNumSamples * 4).assumingMemoryBound(to: UInt16.self)
      for index in 0..<destNumSamples {
        let value = fromView[index]
        toView[index * 2] = value
        toView[index * 2 + 1] = value
      }
      handler()
      offsetNumSamples += destNumSamples / 2
    }
  }

  func copyMonoToStereoWithSwap(
    fromData: UnsafeRawPointer, toData: UnsafeMutableRawPointer, numSamples: Int,
    handler: () -> Void
  ) {
    var offsetNumSamples = 0
    while offsetNumSamples < numSamples {
      let fromView = fromData.advanced(by: offsetNumSamples * 2).assumingMemoryBound(
        to: UInt16.self)
      let toView = toData.advanced(by: offsetNumSamples * 4).assumingMemoryBound(to: UInt16.self)
      for index in 0..<destNumSamples {
        let value = CFSwapInt16(fromView[index])
        toView[index * 2] = value
        toView[index * 2 + 1] = value
      }
      handler()
      offsetNumSamples += destNumSamples / 2
    }
  }
}

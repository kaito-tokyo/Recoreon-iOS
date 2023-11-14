import CoreAudio

class AudioBufferHandler {
  let byteCount: Int

  init(byteCount: Int) {
    self.byteCount = byteCount
  }

  func copyStereoToStereo(from: UnsafeRawPointer, to: UnsafeMutableRawPointer) {
    to.copyMemory(from: from, byteCount: byteCount)
  }

  func copyStereoToStereoWithSwap(from: UnsafeRawPointer, to: UnsafeMutableRawPointer) {
    let fromView = from.assumingMemoryBound(to: UInt16.self)
    let toView = to.assumingMemoryBound(to: UInt16.self)
    for index in 0..<byteCount / 2 {
      let value = CFSwapInt16BigToHost(fromView[index])
      toView[index] = value
    }
  }

  func copyMonoToStereoWithSwap(from: UnsafeRawPointer, to: UnsafeMutableRawPointer) {
    let fromView = from.assumingMemoryBound(to: UInt16.self)
    let toView = to.assumingMemoryBound(to: UInt16.self)
    for index in 0..<byteCount / 4 {
      let value = CFSwapInt16BigToHost(fromView[index])
      toView[index * 2] = value
      toView[index * 2 + 1] = value
    }
  }
}

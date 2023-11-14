import CoreAudio

class AudioBufferHandler {
  let byteCount: Int
  let buf: UnsafeMutableRawPointer

  init(buf: UnsafeMutableRawPointer, byteCount: Int) {
    self.buf = buf
    self.byteCount = byteCount
  }

  func copyStereoToStereo(from: UnsafeRawPointer) {
    buf.copyMemory(from: from, byteCount: byteCount)
  }

  func copyStereoToStereoWithSwap(from: UnsafeRawPointer) {
    let fromView = from.assumingMemoryBound(to: UInt16.self)
    let bufView = buf.assumingMemoryBound(to: UInt16.self)
    for index in 0..<byteCount / 2 {
      let value = CFSwapInt16BigToHost(fromView[index])
      bufView[index] = value
    }
  }

  func copyMonoToStereoWithSwap(from: UnsafeRawPointer) {
    let fromView = from.assumingMemoryBound(to: UInt16.self)
    let bufView = buf.assumingMemoryBound(to: UInt16.self)
    for index in 0..<byteCount / 4 {
      let value = CFSwapInt16BigToHost(fromView[index])
      bufView[index * 2] = value
      bufView[index * 2 + 1] = value
    }
  }
}

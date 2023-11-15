class Int16SameRateSampler: AudioResampler {
  var copyOperationMode: AudioResamplerCopyOperationMode?
  var fromNumSamples: Int?
  var fromData: UnsafeRawPointer?
  let toNumSamples: Int
  var toData: UnsafeMutableRawPointer?

  private var offsetNumSamples: Int = 0
  private let leftPlane: UnsafeMutableBufferPointer<Int16>
  private let rightPlane: UnsafeMutableBufferPointer<Int16>

  init(toNumSamples: Int) {
    self.toNumSamples = toNumSamples
    leftPlane = .allocate(capacity: toNumSamples / 2)
    rightPlane = .allocate(capacity: toNumSamples / 2)
  }

  func reset() {
    self.offsetNumSamples = 0
  }

  func hasNext() -> Bool {
    if let fromNumSamples = self.fromNumSamples {
      return offsetNumSamples < fromNumSamples
    } else {
      return false
    }
  }

  func doCopy() -> Bool {
    guard
      let copyOperationMode = self.copyOperationMode,
      let fromNumSamples = self.fromNumSamples,
      let fromData = self.fromData,
      let toData = self.toData
    else { return false }

    switch copyOperationMode {
    case .monoToStereo:
      monoToStereoStep(fromNumSamples: fromNumSamples, fromData: fromData, toData: toData)
    case .monoToStereoWithSwap:
      monoToStereoWithSwapStep(fromNumSamples: fromNumSamples, fromData: fromData, toData: toData)
    case .stereoToStereo:
      stereoToStereoStep(fromNumSamples: fromNumSamples, fromData: fromData, toData: toData)
    case .stereoToStereoWithSwap:
      stereoToStereoWithSwapStep(fromNumSamples: fromNumSamples, fromData: fromData, toData: toData)
    }

    return true
  }

  private func monoToStereoStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 2).assumingMemoryBound(
      to: Int16.self)
    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      let value = fromView[index]
      toView[index * 2] = value
      toView[index * 2 + 1] = value
    }
    offsetNumSamples += toNumSamples
  }

  private func monoToStereoWithSwapStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 2).assumingMemoryBound(
      to: Int16.self)
    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      let value = fromView[index].byteSwapped
      toView[index * 2] = value
      toView[index * 2 + 1] = value
    }
    offsetNumSamples += toNumSamples
  }

  private func stereoToStereoStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 4)
    toData.copyMemory(from: fromView, byteCount: toNumSamples * 4)
    offsetNumSamples += toNumSamples
  }

  private func stereoToStereoWithSwapStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 4).assumingMemoryBound(
      to: Int16.self)
    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples * 2 {
      let value = fromView[index].byteSwapped
      toView[index] = value
    }
    offsetNumSamples += toNumSamples
  }
}

class Int16DoubleUpsampler: AudioResampler {
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

    for index in 0..<toNumSamples / 2 {
      let value = fromView[index]
      leftPlane[index] = value
      rightPlane[index] = value
    }

    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      if index % 2 == 0 {
        toView[index * 2] = leftPlane[index / 2]
        toView[index * 2 + 1] = rightPlane[index / 2]
      } else {
        toView[index * 2] = 0
        toView[index * 2 + 1] = 0
      }
    }
    offsetNumSamples += toNumSamples / 2
  }

  private func monoToStereoWithSwapStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 2).assumingMemoryBound(
      to: Int16.self)

    for index in 0..<toNumSamples / 2 {
      let value = fromView[index].byteSwapped
      leftPlane[index] = value
      rightPlane[index] = value
    }

    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      if index % 2 == 0 {
        toView[index * 2] = leftPlane[index / 2]
        toView[index * 2 + 1] = rightPlane[index / 2]
      } else {
        toView[index * 2] = 0
        toView[index * 2 + 1] = 0
      }
    }
    offsetNumSamples += toNumSamples / 2
  }

  private func stereoToStereoStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 4).assumingMemoryBound(
      to: Int16.self)

    for index in 0..<toNumSamples / 2 {
      leftPlane[index] = fromView[index * 2]
      rightPlane[index] = fromView[index * 2 + 1]
    }

    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      if index % 2 == 0 {
        toView[index * 2] = leftPlane[index / 2]
        toView[index * 2 + 1] = rightPlane[index / 2]
      } else {
        toView[index * 2] = 0
        toView[index * 2 + 1] = 0
      }
    }
    offsetNumSamples += toNumSamples / 2
  }

  private func stereoToStereoWithSwapStep(
    fromNumSamples: Int,
    fromData: UnsafeRawPointer,
    toData: UnsafeMutableRawPointer
  ) {
    let fromView = fromData.advanced(by: offsetNumSamples * 4).assumingMemoryBound(
      to: Int16.self)

    for index in 0..<toNumSamples / 2 {
      leftPlane[index] = fromView[index * 2].byteSwapped
      rightPlane[index] = fromView[index * 2 + 1].byteSwapped
    }

    let toView = toData.assumingMemoryBound(to: Int16.self)
    for index in 0..<toNumSamples {
      if index % 2 == 0 {
        toView[index * 2] = leftPlane[index / 2]
        toView[index * 2 + 1] = rightPlane[index / 2]
      } else {
        toView[index * 2] = 0
        toView[index * 2 + 1] = 0
      }
    }
    offsetNumSamples += toNumSamples / 2
  }
}

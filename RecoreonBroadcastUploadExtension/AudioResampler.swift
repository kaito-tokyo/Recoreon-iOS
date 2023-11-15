enum AudioResamplerCopyOperationMode {
  case monoToStereo
  case monoToStereoWithSwap
  case stereoToStereo
  case stereoToStereoWithSwap
}

protocol AudioResampler {
  var copyOperationMode: AudioResamplerCopyOperationMode? { get set }
  var fromNumSamples: Int? { get set }
  var fromData: UnsafeRawPointer? { get set }
  var toNumSamples: Int { get }
  var toData: UnsafeMutableRawPointer? { get set }
  func reset()
  func hasNext() -> Bool
  func doCopy() -> Bool
}

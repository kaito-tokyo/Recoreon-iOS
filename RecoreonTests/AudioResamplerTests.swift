import XCTest

final class AudioResamplerTests: XCTestCase {
  var time: Double = 0
  var tincr: Double = 0
  var tincr2: Double = 0

  override func setUpWithError() throws {
  }

  override func tearDownWithError() throws {
  }

  func setUpWriter(filename: String) -> ScreenRecordWriter {
    let documentsPath = NSHomeDirectory() + "/Documents"
    try? FileManager.default.createDirectory(
      atPath: documentsPath, withIntermediateDirectories: true)
    let path = "\(documentsPath)/\(filename)"

    let writer = ScreenRecordWriter()
    writer.openAudioCodec("aac_at")
    writer.openOutputFile(path)
    writer.addAudioStream(0, sampleRate: 48000, bitRate: 64000)
    writer.openAudio(0)
    writer.startOutput()
    return writer
  }

  func tearDownWriter(_ writer: ScreenRecordWriter) {
    writer.finishStream(0)
    writer.finishOutput()
    writer.closeStream(0)
    writer.closeOutput()
  }

  func setUpDummyAudio(sampleRate: Double) {
    time = 0
    tincr = 2 * Double.pi * 330.0 / sampleRate
    tincr2 = 2 * Double.pi * 330.0 / sampleRate / sampleRate
  }

  func getDummyAudioSample() -> Int16 {
    time += tincr
    tincr += tincr2
    return Int16(sin(time) * 10000)
  }

  func resample(
    _ writer: ScreenRecordWriter,
    _ resampler: AudioResampler,
    sampleRate: Int,
    isByteSwapped: Bool,
    isMono: Bool
  ) {
    var resampler = resampler
    let fromData = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: 2)
    let fromView = fromData.assumingMemoryBound(to: Int16.self)
    var outputPTS: Int64 = 0

    let numSamples = isMono ? 2048 : 1024
    let numFrames = sampleRate / numSamples

    for _ in 0..<numFrames {
      for index in 0..<numSamples {
        var value = getDummyAudioSample()
        if isByteSwapped {
          value = value.byteSwapped
        }
        if isMono {
          fromView[index] = value
        } else {
          fromView[index * 2] = value
          fromView[index * 2 + 1] = value
        }
      }

      resampler.reset()
      resampler.fromData = UnsafeRawPointer(fromData)
      resampler.fromNumSamples = numSamples
      while resampler.hasNext() {
        writer.makeFrameWritable(0)
        resampler.toData = writer.getBaseAddress(0, ofPlane: 0)
        if !resampler.doCopy() {
          break
        }
        writer.writeAudio(0, outputPTS: outputPTS)
        outputPTS += 1024
      }
    }
  }

  func testInt16DoubleUpsamplerMonoToStereo() throws {
    setUpDummyAudio(sampleRate: 24000)
    let writer = setUpWriter(filename: "testInt16DoubleUpsamplerMonoToStereo.mkv")
    let resampler = Int16DoubleUpsampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .monoToStereo
    resample(writer, resampler, sampleRate: 24000, isByteSwapped: false, isMono: true)
    tearDownWriter(writer)
  }

  func testInt16DoubleUpsamplerMonoToStereoWithSwap() throws {
    setUpDummyAudio(sampleRate: 24000)
    let writer = setUpWriter(filename: "testInt16DoubleUpsamplerMonoToStereoWithSwap.mkv")
    let resampler = Int16DoubleUpsampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .monoToStereoWithSwap
    resample(writer, resampler, sampleRate: 24000, isByteSwapped: true, isMono: true)
    tearDownWriter(writer)
  }

  func testInt16DoubleUpsamplerStereoToStereo() throws {
    setUpDummyAudio(sampleRate: 24000)
    let writer = setUpWriter(filename: "testInt16DoubleUpsamplerStereoToStereo.mkv")
    let resampler = Int16DoubleUpsampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .stereoToStereo
    resample(writer, resampler, sampleRate: 24000, isByteSwapped: false, isMono: false)
    tearDownWriter(writer)
  }

  func testInt16DoubleUpsamplerStereoToStereoWithSwap() throws {
    setUpDummyAudio(sampleRate: 24000)
    let writer = setUpWriter(filename: "testInt16DoubleUpsamplerStereoToStereoWithSwap.mkv")
    let resampler = Int16DoubleUpsampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .stereoToStereoWithSwap
    resample(writer, resampler, sampleRate: 24000, isByteSwapped: true, isMono: false)
    tearDownWriter(writer)
  }

  func testInt16SameRateSamplerMonoToStereo() throws {
    setUpDummyAudio(sampleRate: 48000)
    let writer = setUpWriter(filename: "testInt16SameRateSamplerMonoToStereo.mkv")
    let resampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .monoToStereo
    resample(writer, resampler, sampleRate: 48000, isByteSwapped: false, isMono: true)
    tearDownWriter(writer)
  }

  func testInt16SameRateSamplerMonoToStereoWithSwap() throws {
    setUpDummyAudio(sampleRate: 48000)
    let writer = setUpWriter(filename: "testInt16SameRateSamplerMonoToStereoWithSwap.mkv")
    let resampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .monoToStereoWithSwap
    resample(writer, resampler, sampleRate: 48000, isByteSwapped: true, isMono: true)
    tearDownWriter(writer)
  }

  func testInt16SameRateSamplerStereoToStereo() throws {
    setUpDummyAudio(sampleRate: 48000)
    let writer = setUpWriter(filename: "testInt16SameRateSamplerStereoToStereo.mkv")
    let resampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .stereoToStereo
    resample(writer, resampler, sampleRate: 48000, isByteSwapped: false, isMono: false)
    tearDownWriter(writer)
  }

  func testInt16SameRateSamplerStereoToStereoWithSwap() throws {
    setUpDummyAudio(sampleRate: 48000)
    let writer = setUpWriter(filename: "testInt16SameRateSamplerStereoToStereoWithSwap.mkv")
    let resampler = Int16SameRateSampler(toNumSamples: writer.getNumSamples(0))
    resampler.copyOperationMode = .stereoToStereoWithSwap
    resample(writer, resampler, sampleRate: 48000, isByteSwapped: true, isMono: false)
    tearDownWriter(writer)
  }
}

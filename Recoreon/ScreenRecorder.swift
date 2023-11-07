import ReplayKit

class ScreenRecorder {
  var isActive = false
  let matroska = Matroska()

  func startRecording() {
    if isActive {
      RPScreenRecorder.shared().stopCapture()
      self.matroska.close()
      return
    }
    let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    matroska.open(dir.appending(component: "test.mkv").path())
    isActive = true
    RPScreenRecorder.shared().startCapture { sampleBuffer, sampleBufferType, error in
      if error != nil {
        print("Error receiving sample buffer for in app capture")
      } else {
        switch sampleBufferType {
        case .video:
          guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
          }
          CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
          let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
          let cbcrPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
          let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
          let cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
          print(yBytesPerRow)
          print(cbcrBytesPerRow)
          self.matroska.writeVideo(
            yPlane, yLinesize: yBytesPerRow, cbcr: cbcrPlane, cbcrLinesize: cbcrBytesPerRow)
          CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        case .audioApp:
          let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)!
          let desc = CMAudioFormatDescriptionGetStreamBasicDescription(fmt)
          var audioBufferList = AudioBufferList()
          var blockBuffer: CMBlockBuffer?
          CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: &audioBufferList,
            bufferListSize: MemoryLayout<AudioBufferList>.size,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer)
          self.matroska.writeAudio(&audioBufferList)
        case .audioMic:
          print("c")
        default:
          print("Unable to process sample buffer")
        }
      }
    } completionHandler: {
    }
  }
}

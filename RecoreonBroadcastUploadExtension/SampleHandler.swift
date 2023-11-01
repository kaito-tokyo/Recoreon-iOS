//
//  SampleHandler.swift
//  RecoreonBroadcastUploadExtension
//
//  Created by Kaito Udagawa on 2023/11/02.
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    var matroska: Matroska?

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        matroska = Matroska()
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.github.umireon.Recoreon")
        matroska?.open(dir?.appending(component: "aaa.mkv").path())
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
//        matroska?.close()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
              return
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            let yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)
            let cbcrPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)
            let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let cbcrBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
            self.matroska?.writeVideo(yPlane, yLinesize: yBytesPerRow, cbcr: cbcrPlane, cbcrLinesize: cbcrBytesPerRow)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            break
        case RPSampleBufferType.audioApp:
            // Handle audio sample buffer for app audio
            break
        case RPSampleBufferType.audioMic:
            // Handle audio sample buffer for mic audio
            break
        @unknown default:
            // Handle other sample buffer types
            fatalError("Unknown type of sample buffer")
        }
    }
}

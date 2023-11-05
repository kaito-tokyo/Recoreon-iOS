//
//  SampleHandler.swift
//  RecoreonBroadcastUploadExtension
//
//  Created by Kaito Udagawa on 2023/11/02.
//

import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    var matroska: Matroska?
    
    let dateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions.remove(.withDashSeparatorInDate)
        formatter.formatOptions.remove(.withColonSeparatorInTime)
        formatter.formatOptions.remove(.withTimeZone)
        formatter.timeZone = TimeZone.current
        return formatter
    }()
    
    func generateFileName(date: Date, ext: String = "mkv") -> String {
        let dateString = dateFormatter.string(from: date)
        return "Recoreon\(dateString).\(ext)"
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        matroska = Matroska()
        let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.github.umireon.Recoreon")?.appendingPathComponent("Documents")
        try? FileManager.default.createDirectory(at: dir!, withIntermediateDirectories: true)
        let filename = generateFileName(date: Date())
        matroska?.open(dir?.appending(component: filename).path())
    }
    
    override func broadcastPaused() {
        // User has requested to pause the broadcast. Samples will stop being delivered.
    }
    
    override func broadcastResumed() {
        // User has requested to resume the broadcast. Samples delivery will resume.
    }
    
    override func broadcastFinished() {
        matroska?.close()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            self.matroska?.writeVideo(sampleBuffer)
            break
        case RPSampleBufferType.audioApp:
            self.matroska?.writeAudio(sampleBuffer)
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

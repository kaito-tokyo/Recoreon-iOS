//
//  ContentView.swift
//  Recoreon
//
//  Created by Kaito Udagawa on 2023/11/01.
//

import SwiftUI

struct VideoEntry {
    let id: String
    let url: URL
    let uiImage: UIImage
}

struct ContentView: View {
    let paths = RecoreonPaths()
    let thumbnailExtrator = ThumbnailExtractor()
    let videoEncoder = VideoEncoder()
    
    func listVideoEntries() -> [VideoEntry] {
        paths.ensureDirectoriesExists()
        var entries: [VideoEntry] = []
        for url in paths.listMkvRecordURLs() {
            guard let thumbURL = paths.getThumbnailURL(videoURL: url) else { continue }
            print(thumbURL)
            if (!FileManager.default.fileExists(atPath: thumbURL.path())) {
                thumbnailExtrator.extract(url, thumbnailURL: thumbURL)
            }
            guard let uiImage = UIImage(contentsOfFile: thumbURL.path()) else { continue }
            guard let cgImage = uiImage.cgImage else { continue }
            var cropped: CGImage?
            if (cgImage.width > cgImage.height) {
                let x = (cgImage.width - cgImage.height) / 2
                cropped = cgImage.cropping(to: CGRect(x: x, y: 0, width: cgImage.height, height: cgImage.height))
            } else {
                let y = (cgImage.height - cgImage.width) / 2
                cropped = cgImage.cropping(to: CGRect(x: 0, y: y, width: cgImage.width, height: cgImage.width))
            }
            entries.append(VideoEntry(id: url.lastPathComponent, url: url, uiImage: UIImage(cgImage: cropped!)))
        }
        return entries
    }
    
    @State var encodingProgress: Double = 0.0
    @State var videoEntries: [VideoEntry] = []
    @State var showingEncodeCompletedAlert = false
    
    var body: some View {
        VStack {
            Text("Encoding progress")
            ProgressView(value: encodingProgress)
            List {
                ForEach(videoEntries, id: \.id) { entry in
                    Button {
                        Task {
                            try? FileManager.default.copyItem(atPath: entry.url.path(), toPath: NSHomeDirectory() + "/Documents/" + entry.url.lastPathComponent)
                            let outputURL = paths.getEncodedVideoURL(videoURL: entry.url, suffix: "discord")!
                            let isSuccessful = await videoEncoder.encode(entry.url, outputURL: outputURL, progressHandler: { progress in
                                Task { @MainActor in
                                    encodingProgress = min(progress, 1.0)
                                }
                            })
                            if (isSuccessful) {
                                UISaveVideoAtPathToSavedPhotosAlbum(outputURL.path(), nil, nil, nil)
                                showingEncodeCompletedAlert = true
                            } else {
                                
                            }
                        }
                    } label: {
                        Image(uiImage: entry.uiImage).resizable().scaledToFit()
                    }.alert("Encoding completed", isPresented: $showingEncodeCompletedAlert, actions: {
                        Button("OK") {}
                    })
                }
            }.onAppear {
                videoEntries = listVideoEntries()
            }
        }
    }
}

//#Preview {
//    ContentView()
//}

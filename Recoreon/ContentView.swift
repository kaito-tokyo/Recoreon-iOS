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
            let thumbURL = paths.getThumbnailURL(videoURL: url)
            guard let uiImage = thumbnailExtrator.extract(url, thumbnailURL: thumbURL) else { continue }
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
    
    var body: some View {
        VStack {
            ProgressView(value: encodingProgress)
            List {
                ForEach(videoEntries, id: \.id) { entry in
                    Button {
                        Task {
                            let outputURL = paths.getEncodedVideoURL(videoURL: entry.url, suffix: "discord")!
                            let isSuccessful = await videoEncoder.encode(entry.url, outputURL: outputURL, progressHandler: { progress in
                                Task { @MainActor in
                                    print(progress)
                                    encodingProgress = progress
                                }
                            })
                            if (isSuccessful) {
                                let publicPath = NSHomeDirectory() + "/Documents/" + outputURL.lastPathComponent
                                if (FileManager.default.fileExists(atPath: publicPath)) {
                                    try? FileManager.default.removeItem(atPath: publicPath)
                                }
                                try? FileManager.default.copyItem(atPath: outputURL.path(), toPath: publicPath)
                            }
                        }
                    } label: {
                        Image(uiImage: entry.uiImage).resizable().scaledToFit()
                    }
                }
            }.onAppear {
                videoEntries = listVideoEntries()
            }
        }
    }
}

#Preview {
    ContentView()
}

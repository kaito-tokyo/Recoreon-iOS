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
    
    var body: some View {
        List {
            ForEach(listVideoEntries(), id: \.id) { entry in
                Button(action: {
                    let outputURL = paths.getEncodedVideoURL(videoURL: entry.url, suffix: "discord")!
                    videoEncoder.encode(entry.url, outputURL: outputURL)
                    try? FileManager.default.copyItem(atPath: outputURL.path(), toPath:  NSHomeDirectory() + "/Documents/" + outputURL.lastPathComponent)
                }, label: {
                    Image(uiImage: entry.uiImage).resizable().scaledToFit()
                })
            }
        }
    }
}

#Preview {
    ContentView()
}

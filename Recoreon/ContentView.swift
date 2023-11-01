//
//  ContentView.swift
//  Recoreon
//
//  Created by Kaito Udagawa on 2023/11/01.
//

import SwiftUI

struct ContentView: View {
    let recorder = ScreenRecorder()
    var body: some View {
        VStack {
            Button(action: {
                recorder.startRecording()
            }, label: {
                Text("Start Recording")
            })
            Button(action: {
                let appGroupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.github.umireon.Recoreon")
                let mkv = appGroupDir!.appendingPathComponent("aaa.mkv")
                let homeDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let toMkv = homeDir.appendingPathComponent("aaa.mkv")
                try? FileManager.default.removeItem(at: toMkv)
                try? FileManager.default.copyItem(at: mkv, to: toMkv)
            }, label: {
                Text("Export all")
            })
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

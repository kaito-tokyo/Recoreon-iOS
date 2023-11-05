//
//  ContentView.swift
//  Recoreon
//
//  Created by Kaito Udagawa on 2023/11/01.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Button(action: {
                let homeDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let appGroupDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.github.umireon.Recoreon")?.appendingPathComponent("Documents")
                let fromURLs = try! FileManager.default.contentsOfDirectory(at: appGroupDir!, includingPropertiesForKeys: nil)
                for fromURL in fromURLs {
                    let filename = fromURL.pathComponents.last
                    let toURL = homeDir.appendingPathComponent(filename!)
                    try? FileManager.default.moveItem(at: fromURL, to: toURL)
                }
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

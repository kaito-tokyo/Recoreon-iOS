import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  @State var entries: [RecordedVideoEntry] = []

  @State var encodingScreenIsPresented: Bool = false

  @State var encodingURL = URL(fileURLWithPath: "")
  @State var encodingUIImage = UIImage(named: "AppIcon")!

  let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

  var body: some View {
    VStack {
      List {
        LazyVGrid(columns: columns) {
          ForEach(entries) { entry in
            Button {
              encodingScreenIsPresented = true
              encodingURL = entry.url
              encodingUIImage = entry.uiImage
            } label: {
              Image(uiImage: entry.uiImage).resizable().scaledToFit()
            }
          }
        }
      }
    }.sheet(isPresented: $encodingScreenIsPresented) {
      EncodingRecordedVideoView(
        recordedVideoManipulator: recordedVideoManipulator, url: $encodingURL, uiImage: $encodingUIImage)
    }.onAppear {
      entries = recordedVideoManipulator.listVideoEntries()
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}

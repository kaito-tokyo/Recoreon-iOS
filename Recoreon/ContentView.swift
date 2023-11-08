import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  @State var entries: [RecordedVideoEntry] = []

  @State var encodingScreenIsPresented: Bool = false

  @State var encodingEntry = RecordedVideoEntry(
    url: URL(fileURLWithPath: ""), uiImage: UIImage(named: "AppIcon")!)

  let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

  var body: some View {
    VStack {
      List {
        LazyVGrid(columns: columns) {
          ForEach(entries) { entry in
            Button {
              encodingScreenIsPresented = true
              encodingEntry = entry
            } label: {
              Image(uiImage: entry.uiImage).resizable().scaledToFit()
            }.buttonStyle(.borderless)
          }
        }
      }
    }.sheet(isPresented: $encodingScreenIsPresented) {
      EncodingRecordedVideoView(
        recordedVideoManipulator: recordedVideoManipulator, entry: $encodingEntry)
    }.onAppear {
      entries = recordedVideoManipulator.listVideoEntries()
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}

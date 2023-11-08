import SwiftUI

struct ContentView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol

  @State var entries: [RecordedVideoEntry] = []

  @State var encodingScreenIsPresented: Bool = false

  @State private var encodingEntry: RecordedVideoEntry = RecordedVideoEntry(
    url: URL(fileURLWithPath: ""), uiImage: UIImage(named: "AppIcon")!)

  @State private var encodingProgress: Double = 0.0

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
            }
          }
        }
      }
    }.sheet(isPresented: $encodingScreenIsPresented) {
      EncodingRecordedVideoView(
        recordedVideoManipulator: recordedVideoManipulator, encodingEntry: encodingEntry)
    }.onAppear {
      entries = recordedVideoManipulator.listVideoEntries()
    }
  }
}

#Preview {
  ContentView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}

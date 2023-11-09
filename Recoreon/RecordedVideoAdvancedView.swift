import ReplayKit
import SwiftUI

struct RecordedVideoAdvancedView: View {
  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  var body: some View {
    NavigationStack {
      List {
        ForEach(recordedVideoEntries) { entry in
          NavigationLink {
            Image(uiImage: entry.uiImage).resizable().scaledToFit()
              .navigationTitle(entry.url.lastPathComponent)
          } label: {
            VStack {
              HStack {
                Text(entry.url.lastPathComponent)
                Spacer()
              }
              HStack {
                Text(Date().formatted())
                Text("1GB")
                Spacer()
              }
            }
          }.buttonStyle(.plain)
        }
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

#Preview {
  let recordedVideoManipulator = RecordedVideoManipulatorMock()
  @State var recordedVideoEntries = recordedVideoManipulator.listVideoEntries()

  return RecordedVideoAdvancedView(recordedVideoEntries: $recordedVideoEntries)
}

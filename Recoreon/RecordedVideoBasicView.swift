import ReplayKit
import SwiftUI

struct RecordedVideoBasicView: View {
  let recordedVideoManipulator: RecordedVideoManipulator

  @State var entries: [RecordedVideoEntry] = []

  @State var encodingScreenIsPresented: Bool = false

  @State var encodingEntry = RecordedVideoEntry(
    url: URL(fileURLWithPath: ""), uiImage: UIImage(named: "AppIcon")!)

  @State var selection: Set<URL> = []

  @State var editMode: EditMode = .inactive

  let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

  @State var showingBroadcastPicker: Bool = false

  var body: some View {
    NavigationStack {
      VStack {
        List {
          LazyVGrid(columns: columns) {
            ForEach(entries) { entry in
              Button {
                if editMode.isEditing == true {
                  if selection.contains(entry.id) {
                    selection.remove(entry.id)
                  } else {
                    selection.insert(entry.id)
                  }
                } else {
                  encodingScreenIsPresented = true
                  encodingEntry = entry
                }
              } label: {
                ZStack {
                  if selection.contains(entry.id) {
                    Image(uiImage: entry.uiImage).resizable().scaledToFit().border(
                      Color.blue, width: 5.0)
                    Image(systemName: "checkmark.circle.fill").scaleEffect(
                      CGSize(width: 2.0, height: 2.0), anchor: .center
                    ).padding()
                  } else {
                    Image(uiImage: entry.uiImage).resizable().scaledToFit()
                  }
                }.onChange(of: editMode) {
                  selection.removeAll()
                }
              }.buttonStyle(.borderless)
            }
          }
        }
        Button {
          print(selection)
        } label: {
          Image(systemName: "trash")
        }
      }.sheet(isPresented: $encodingScreenIsPresented) {
        EncodingRecordedVideoView(
          recordedVideoManipulator: recordedVideoManipulator, entry: $encodingEntry)
      }.onAppear {
        entries = recordedVideoManipulator.listVideoEntries()
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem {
          EditButton().onChange(of: editMode) {
            selection.removeAll()
          }
        }
      }.environment(\.editMode, $editMode)
    }
  }
}

#Preview {
  RecordedVideoBasicView(recordedVideoManipulator: RecordedVideoManipulatorMock())
}

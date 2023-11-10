import ReplayKit
import SwiftUI

struct RecordedVideoBasicView: View {
  let recordedVideoService: RecordedVideoService

  @Binding var recordedVideoEntries: [RecordedVideoEntry]

  @State var encodingScreenIsPresented: Bool = false

  @State var encodingEntry = RecordedVideoEntry(
    url: URL(fileURLWithPath: ""),
    encodedVideoCollection: EncodedVideoCollection(encodedVideoURLs: [:])
  )

  @State var selection: Set<URL> = []

  @State var editMode: EditMode = .inactive

  let columns: [GridItem] = Array(repeating: .init(.flexible()), count: 3)

  @State var showingBroadcastPicker: Bool = false

  var body: some View {
    NavigationStack {
      VStack {
        List {
          LazyVGrid(columns: columns) {
            ForEach(recordedVideoEntries) { entry in
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
                    Image(uiImage: UIImage()).resizable().scaledToFit().border(
                      Color.blue, width: 5.0)
                    Image(systemName: "checkmark.circle.fill").scaleEffect(
                      CGSize(width: 2.0, height: 2.0), anchor: .center
                    ).padding()
                  } else {
                    Image(uiImage: UIImage()).resizable().scaledToFit()
                  }
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
          recordedVideoService: recordedVideoService,
          entry: encodingEntry
        )
      }
      .navigationTitle("List of recorded videos")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem {
          EditButton()
        }
      }.environment(\.editMode, $editMode)
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()
    return RecordedVideoBasicView(
      recordedVideoService: service,
      recordedVideoEntries: $entries
    )
  }
#endif

import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct ScreenRecordListView: View {
  let recoreonServices: RecoreonServices
  @ObservedObject var screenRecordStore: ScreenRecordStore
  @Binding var path: NavigationPath

  @State private var editMode: EditMode = .inactive
  @State private var selectedScreenRecordEntries = Set<ScreenRecordEntry>()
  @State private var isRemoveConfirmationPresented: Bool = false

  func screenRecordEntry(_ entry: ScreenRecordEntry) -> some View {
    return HStack {
      if editMode.isEditing {
        if selectedScreenRecordEntries.contains(entry) {
          Image(systemName: "checkmark.circle")
            .foregroundColor(.green)
        } else {
          Image(systemName: "circle")
        }
      }
      VStack {
        HStack {
          Text(entry.url.lastPathComponent)
          Spacer()
        }
        HStack {
          Text(entry.creationDate.formatted())
          Text(byteCountFormatter.string(fromByteCount: Int64(entry.size)))
          Spacer()
        }
      }
    }
  }

  func screenRecordList() -> some View {
    return List {
      ForEach(screenRecordStore.screenRecordEntries) { entry in
        let detailViewRoute = ScreenRecordDetailViewRoute(screenRecordEntry: entry)
        if editMode.isEditing {
          Button {
            if selectedScreenRecordEntries.contains(entry) {
              selectedScreenRecordEntries.remove(entry)
            } else {
              selectedScreenRecordEntries.insert(entry)
            }
          } label: {
            screenRecordEntry(entry)
          }
          .foregroundStyle(.foreground)
        } else {
          NavigationLink(value: detailViewRoute) {
            screenRecordEntry(entry)
          }
        }
      }
    }
  }

  func shareLinkButton() -> some View {
    let shareURLs = selectedScreenRecordEntries.flatMap { screenRecordEntry in

      let recordNoteURLs = recordNoteService.listRecordNoteEntries(
        screenRecordEntry: screenRecordEntry
      ).map { $0.url }
      return [screenRecordEntry.url] + recordNoteURLs
    }
    return VStack {
      Spacer()
      HStack {
        Spacer()
        ShareLink(
          items: shareURLs,
          label: {
            Image(systemName: "square.and.arrow.up")
              .resizable()
              .scaledToFill()
              .frame(width: 32, height: 32)
              .tint(Color.white)
              .padding(.all, 20)
              .background(selectedScreenRecordEntries.isEmpty ? Color.gray : Color.blue)
              .clipShape(Circle())
          }
        )
        .disabled(selectedScreenRecordEntries.isEmpty)
        Button {
          isRemoveConfirmationPresented = true
        } label: {
          Image(systemName: "trash")
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .tint(Color.white)
            .padding(.all, 20)
            .background(selectedScreenRecordEntries.isEmpty ? Color.gray : Color.red)
            .clipShape(Circle())
        }
        .disabled(selectedScreenRecordEntries.isEmpty)
        .padding(.trailing, 10)
        .padding(.bottom, 10)
      }
      .alert(isPresented: $isRemoveConfirmationPresented) {
        Alert(
          title: Text("Are you sure to remove all of the selected screen records?"),
          primaryButton: .destructive(Text("OK")) {
            for entry in selectedScreenRecordEntries {
              screenRecordService.removeScreenRecordAndRelatedFiles(screenRecordEntry: entry)
            }
            screenRecordStore.update()
          },
          secondaryButton: .cancel()
        )
      }
    }
  }

  var body: some View {
    ZStack {
      screenRecordList()
      shareLinkButton()
    }
    .navigationTitle("List of screen records")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: ScreenRecordDetailViewRoute.self) { route in
      ScreenRecordDetailView(
        screenRecordService: screenRecordService, recordNoteService: recordNoteService,
        screenRecordStore: screenRecordStore, path: $path,
        screenRecordEntry: route.screenRecordEntry)
    }
    .toolbar {
      EditButton()
    }
    .environment(\.editMode, $editMode)
    .onChange(of: editMode) { newValue in
      if newValue == .inactive {
        selectedScreenRecordEntries.removeAll()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let screenRecordService = ScreenRecordServiceMock()
    let recordNoteService = RecordNoteServiceMock()
    @State var path = NavigationPath()
    @StateObject var screenRecordStore = ScreenRecordStore(screenRecordService: screenRecordService)

    return NavigationStack {
      ScreenRecordListView(
        screenRecordService: screenRecordService,
        recordNoteService: recordNoteService,
        screenRecordStore: screenRecordStore,
        path: $path
      )
    }
  }
#endif

import AVKit
import RecoreonCommon
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

  @AppStorage(
    AppGroupsPreferenceService.isRecordingKey,
    store: AppGroupsPreferenceService.userDefaults
  ) private var isRecording: Bool?

  @AppStorage(
    AppGroupsPreferenceService.isRecordingTimestampKey,
    store: AppGroupsPreferenceService.userDefaults
  ) private var isRecordingTimestamp: Double?

  @AppStorage(
    AppGroupsPreferenceService.recordingURLKey,
    store: AppGroupsPreferenceService.userDefaults
  ) private var recordingURL: String?

  func getOngoingScreenRecordEntry() -> ScreenRecordEntry? {
    guard let isRecordingTimestamp = isRecordingTimestamp else { return nil }
    let elapsedTime = Date().timeIntervalSince1970 - isRecordingTimestamp
    if isRecording != true || elapsedTime > 1 {
      return nil
    }
    let screenRecordEntries = screenRecordStore.screenRecordEntries
    let ongoingScreenRecordEntry = screenRecordEntries.first { screenRecordEntry in
      return screenRecordEntry.url.absoluteString == recordingURL
    }
    return ongoingScreenRecordEntry
  }

  func screenRecordEntryItem(screenRecordEntry: ScreenRecordEntry) -> some View {
    return VStack {
      HStack {
        Text(screenRecordEntry.url.lastPathComponent)
        Spacer()
      }
      HStack {
        Text(screenRecordEntry.creationDate.formatted())
        Text(byteCountFormatter.string(fromByteCount: Int64(screenRecordEntry.size)))
        Spacer()
      }
      if screenRecordEntry.summaryBody != "" {
        HStack {
          Text(screenRecordEntry.summaryBody)
          Spacer()
        }
      }
    }
  }

  func screenRecordList(screenRecordEntries: [ScreenRecordEntry]) -> some View {
    return Section(header: Text("Saved screen records")) {
      ForEach(screenRecordEntries) { screenRecordEntry in
        Button {
          if editMode.isEditing {
            if selectedScreenRecordEntries.contains(screenRecordEntry) {
              selectedScreenRecordEntries.remove(screenRecordEntry)
            } else {
              selectedScreenRecordEntries.insert(screenRecordEntry)
            }
          } else {
            path.append(
              ScreenRecordDetailViewRoute(
                screenRecordEntry: screenRecordEntry)
            )
          }
        } label: {
          HStack {
            if editMode.isEditing {
              if selectedScreenRecordEntries.contains(screenRecordEntry) {
                Image(systemName: "checkmark.circle")
                  .foregroundColor(.green)
              } else {
                Image(systemName: "circle")
              }
            }
            NavigationLink {
              EmptyView()
            } label: {
              screenRecordEntryItem(screenRecordEntry: screenRecordEntry)
            }
          }
        }
        .foregroundColor(Color.black)
      }
    }
  }

  func shareLinkButton() -> some View {
    let shareURLs = selectedScreenRecordEntries.flatMap { screenRecordEntry in

      let recordNoteURLs = recoreonServices.recordNoteService.listRecordNoteEntries(
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
              recoreonServices.screenRecordService.removeScreenRecordAndRelatedFiles(
                screenRecordEntry: entry)
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
      Form {
        var screenRecordEntries = screenRecordStore.screenRecordEntries
        if let ongoingScreenRecordEntry = getOngoingScreenRecordEntry() {
          let ongoingScreenRecordEntryIndex = screenRecordEntries.firstIndex(
            of: ongoingScreenRecordEntry)
          if let ongoingScreenRecordEntryIndex = ongoingScreenRecordEntryIndex {
            let _ = screenRecordEntries.remove(at: ongoingScreenRecordEntryIndex)
          }

          Section(header: Text("Ongoing screen record")) {
            NavigationLink(
              value: ScreenRecordDetailViewRoute(
                screenRecordEntry: ongoingScreenRecordEntry
              )
            ) {
              screenRecordEntryItem(screenRecordEntry: ongoingScreenRecordEntry)
            }
            .listRowBackground(Color.red)
            .foregroundStyle(Color.white)
          }
        }

        screenRecordList(screenRecordEntries: screenRecordEntries)
      }
      shareLinkButton()
    }
    .navigationTitle("List of screen records")
    .navigationBarTitleDisplayMode(.inline)
    .navigationDestination(for: ScreenRecordDetailViewRoute.self) { route in
      ScreenRecordDetailView(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore,
        path: $path,
        screenRecordEntry: route.screenRecordEntry
      )
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
  struct ScreenRecordListViewContainer: View {
    let recoreonServices: RecoreonServices
    @StateObject var screenRecordStore: ScreenRecordStore
    @State var path = NavigationPath()

    init(
      recoreonServices: RecoreonServices,
      screenRecordStore: ScreenRecordStore
    ) {
      self.recoreonServices = recoreonServices
      _screenRecordStore = StateObject(wrappedValue: screenRecordStore)
    }

    var body: some View {
      TabView {
        NavigationStack(path: $path) {
          ScreenRecordListView(
            recoreonServices: recoreonServices,
            screenRecordStore: screenRecordStore,
            path: $path
          )
        }
      }
    }
  }

  #Preview {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServices.screenRecordService
    )

    let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults!

    appGroupsUserDefaults.set(true, forKey: AppGroupsPreferenceService.isRecordingKey)
    appGroupsUserDefaults.set(
      Date().timeIntervalSince1970, forKey: AppGroupsPreferenceService.isRecordingTimestampKey)
    appGroupsUserDefaults.set(
      screenRecordStore.screenRecordEntries[0].url.absoluteString,
      forKey: AppGroupsPreferenceService.recordingURLKey
    )

    return NavigationStack {
      ScreenRecordListViewContainer(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore
      )
    }
  }
#endif

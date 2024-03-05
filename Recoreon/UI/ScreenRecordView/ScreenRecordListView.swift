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
  @Binding private var path: NavigationPath

  @StateObject private var screenRecordStore: ScreenRecordStore

//  @State private var editMode: EditMode = .inactive
  @State private var selectedScreenRecordEntries = Set<ScreenRecordEntry>()
  @State private var isRemoveConfirmationPresented: Bool = false

  @Environment(\.editMode) private var editMode
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage(
    AppGroupsPreferenceService.ongoingRecordingTimestampKey,
    store: AppGroupsPreferenceService.userDefaults
  ) private var ongoingRecordingTimestamp = 0.0

  @AppStorage(
    AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey,
    store: AppGroupsPreferenceService.userDefaults
  ) private var ongoingRecordingURLAbsoluteString = ""

  init(
    recoreonServices: RecoreonServices,
    path: Binding<NavigationPath>
  ) {
    self.recoreonServices = recoreonServices
    self._path = path

    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServices.screenRecordService
    )
    screenRecordStore.update()
    self._screenRecordStore = StateObject(wrappedValue: screenRecordStore)
  }

  func getOngoingScreenRecordEntry() -> ScreenRecordEntry? {
    let appGroupsPreferenceService = recoreonServices.appGroupsPreferenceService
    let screenRecordEntries = screenRecordStore.screenRecordEntries
    let ongoingScreenRecordEntry = screenRecordEntries.first { screenRecordEntry in
      appGroupsPreferenceService.isRecordingOngoing(
        screenRecordURL: screenRecordEntry.url,
        ongoingRecordingTimestamp: ongoingRecordingTimestamp,
        ongoingRecordingURLAbsoluteString: ongoingRecordingURLAbsoluteString
      )
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
          if editMode?.wrappedValue.isEditing == true {
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
            if editMode?.wrappedValue.isEditing == true {
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
        ShareLink(items: shareURLs) {
          Image(systemName: "square.and.arrow.up")
            .resizable()
            .scaledToFill()
            .frame(width: 32, height: 32)
            .tint(Color.white)
            .padding(.all, 20)
            .background(selectedScreenRecordEntries.isEmpty ? Color.gray : Color.blue)
            .clipShape(Circle())
        }
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
            selectedScreenRecordEntries.removeAll()
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
        path: $path,
        screenRecordStore: screenRecordStore,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .toolbar {
      EditButton()
    }
    .onChange(of: editMode?.wrappedValue.isEditing) { newValue in
      if newValue == false {
        selectedScreenRecordEntries.removeAll()
      }
    }
    .onChange(of: scenePhase) { newValue in
      if newValue == .active {
        screenRecordStore.update()
      }
    }
    .onChange(of: path) { _ in
      screenRecordStore.update()
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
            path: $path
          )
        }
      }
    }
  }

  #Preview("There are no ongoing records") {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServices.screenRecordService
    )

    let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults!

    appGroupsUserDefaults.set(
      Date().timeIntervalSince1970 - 10,
      forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey)
    appGroupsUserDefaults.set(
      screenRecordStore.screenRecordEntries[0].url.absoluteString,
      forKey: AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey
    )

    return NavigationStack {
      ScreenRecordListViewContainer(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore
      )
    }
  }

  #Preview("There is a ongoing record") {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServices.screenRecordService
    )

    let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults!

    appGroupsUserDefaults.set(
      Date().timeIntervalSince1970 + 1000,
      forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey)
    appGroupsUserDefaults.set(
      screenRecordStore.screenRecordEntries[0].url.absoluteString,
      forKey: AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey
    )

    return NavigationStack {
      ScreenRecordListViewContainer(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore
      )
    }
  }
#endif

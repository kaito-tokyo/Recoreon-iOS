import AVKit
import RecoreonCommon
import SwiftUI

struct ScreenRecordDetailViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordDetailView: View {
  let recoreonServices: RecoreonServices
  @Binding var path: NavigationPath
  @ObservedObject var screenRecordStore: ScreenRecordStore
  let screenRecordEntry: ScreenRecordEntry

  @StateObject var recordNoteStore: RecordNoteStore

  @State var isShowingRemoveConfirmation = false

  @State var editingRecordSummaryBody: String = ""

  @State var isAskingNewNoteShortName = false
  @State var newNoteShortName = ""
  @State var isAlertingExistingName = false

  @Environment(\.scenePhase) var scenePhase
  @Environment(\.isPresented) var isPresented

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
    path: Binding<NavigationPath>,
    screenRecordStore: ScreenRecordStore,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.recoreonServices = recoreonServices
    self._path = path
    self.screenRecordStore = screenRecordStore
    self.screenRecordEntry = screenRecordEntry

    let recordNoteStore = RecordNoteStore(
      recordNoteService: recoreonServices.recordNoteService,
      screenRecordEntry: screenRecordEntry
    )
    self._recordNoteStore = StateObject(wrappedValue: recordNoteStore)

    let recordSummaryEntry = recoreonServices.recordNoteService.readRecordSummaryEntry(
      screenRecordEntry: screenRecordEntry)
    self._editingRecordSummaryBody = State(initialValue: recordSummaryEntry.body)
  }

  func recordNoteList() -> some View {
    return Section(header: Text("Notes")) {
      TextField("Enter the summary...", text: $editingRecordSummaryBody)
        .onChange(of: editingRecordSummaryBody) { newValue in
          let recordSummaryURL = recoreonServices.recordNoteService.generateRecordSummaryURL(
            screenRecordEntry: screenRecordEntry
          )
          recordNoteStore.putNote(recordNoteURL: recordSummaryURL, body: newValue)
        }

      ForEach(recordNoteStore.listGeneralRecordNoteEntries()) { recordNoteEntry in
        let recordNoteService = recoreonServices.recordNoteService
        let recordNoteShortName = recordNoteService.extractRecordNoteShortName(
          recordNoteEntry: recordNoteEntry
        )
        Button {
          withAnimation {
            path.append(
              RecordNoteEditorViewRoute(
                recordNoteEntry: recordNoteEntry
              )
            )
          }
        } label: {
          NavigationLink {
            EmptyView()
          } label: {
            Label(recordNoteShortName, systemImage: "doc")
          }
        }
        .accessibilityIdentifier("RecordNoteEntryButton")
      }

      Button {
        isAskingNewNoteShortName = true
      } label: {
        Label("Add", systemImage: "doc.badge.plus")
      }
      .alert("Enter a new note name", isPresented: $isAskingNewNoteShortName) {
        TextField("Name", text: $newNoteShortName)
        Button {
          let recordNoteEntries = recordNoteStore.listRecordNoteEntries()
          let doesNoteExists = recordNoteEntries.contains { recordNoteEntry in
            let shortName = recoreonServices.recordNoteService.extractRecordNoteShortName(
              recordNoteEntry: recordNoteEntry)
            return shortName == newNoteShortName
          }
          if doesNoteExists {
            isAlertingExistingName = true
          } else if !newNoteShortName.isEmpty {
            recordNoteStore.addNote(shortName: newNoteShortName)
          }
          newNoteShortName = ""
        } label: {
          Text("OK")
        }
      }
      .alert(
        "The note with the specified name already exists!", isPresented: $isAlertingExistingName
      ) {
      }
    }
    .onChange(of: scenePhase) { newValue in
      if scenePhase == .active && newValue == .inactive {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: isPresented) { newValue in
      if newValue == false {
        recordNoteStore.saveAllNotes()
      }
    }
    .onChange(of: path) { _ in
      recordNoteStore.saveAllNotes()
    }
  }

  var body: some View {
    let appGroupsPreferenceService = recoreonServices.appGroupsPreferenceService
    let isRecordingOngoing = appGroupsPreferenceService.isRecordingOngoing(
      screenRecordURL: screenRecordEntry.url,
      ongoingRecordingTimestamp: ongoingRecordingTimestamp,
      ongoingRecordingURLAbsoluteString: ongoingRecordingURLAbsoluteString
    )
    Form {
      if isRecordingOngoing {
        Text("This screen record is ongoing!")
          .listRowBackground(Color.red)
          .foregroundStyle(Color.white)
      } else {
        Section {
          Button {
            withAnimation {
              path.append(
                ScreenRecordPreviewViewRoute(
                  screenRecordEntry: screenRecordEntry
                )
              )
            }
          } label: {
            NavigationLink {
              EmptyView()
            } label: {
              Label("Preview", systemImage: "play")
            }
          }
          .accessibilityIdentifier("PreviewButton")

          Button {
            withAnimation {
              path.append(
                ScreenRecordEncoderViewRoute(
                  screenRecordEntry: screenRecordEntry
                )
              )
            }
          } label: {
            NavigationLink {
              EmptyView()
            } label: {
              Label("Encode", systemImage: "film")
            }
          }
          .accessibilityIdentifier("EncodeButton")

          ShareLink(item: screenRecordEntry.url)

          Button {
            isShowingRemoveConfirmation = true
          } label: {
            Label {
              Text("Remove")
            } icon: {
              Image(systemName: "trash")
            }
          }
          .alert(isPresented: $isShowingRemoveConfirmation) {
            Alert(
              title: Text("Are you sure to remove this screen record?"),
              primaryButton: .destructive(Text("OK")) {
                withAnimation {
                  recoreonServices.screenRecordService.removeScreenRecordAndRelatedFiles(
                    screenRecordEntry: screenRecordEntry)
                  screenRecordStore.update()
                  if path.count > 0 {
                    path.removeLast()
                  }
                }
              },
              secondaryButton: .cancel()
            )
          }
        }
      }

      recordNoteList()
    }
    .navigationTitle(screenRecordEntry.url.lastPathComponent)
    .navigationDestination(for: ScreenRecordPreviewViewRoute.self) { route in
      ScreenRecordPreviewView(
        recoreonServices: recoreonServices,
        screenRecordEntry: route.screenRecordEntry
      )
    }
    .navigationDestination(for: ScreenRecordEncoderViewRoute.self) { route in
      ScreenRecordEncoderView(
        recoreonServices: recoreonServices, screenRecordEntry: route.screenRecordEntry)
    }
    .navigationDestination(for: RecordNoteEditorViewRoute.self) { route in
      RecordNoteEditorView(
        path: $path,
        recordNoteStore: recordNoteStore,
        recordNoteEntry: route.recordNoteEntry
      )
    }
  }
}

#if DEBUG
struct ScreenRecordDetailViewContainer: View {
  let recoreonServices: RecoreonServices
  @StateObject var screenRecordStore: ScreenRecordStore
  @State var path: NavigationPath
  let screenRecordEntry: ScreenRecordEntry

  init(
    recoreonServices: RecoreonServices,
    screenRecordStore: ScreenRecordStore,
    path: NavigationPath,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.recoreonServices = recoreonServices
    _screenRecordStore = StateObject(wrappedValue: screenRecordStore)
    _path = State(initialValue: path)
    self.screenRecordEntry = screenRecordEntry
  }

  var body: some View {
    TabView {
      NavigationStack(path: $path) {
        ScreenRecordDetailView(
          recoreonServices: recoreonServices,
          path: $path,
          screenRecordStore: screenRecordStore,
          screenRecordEntry: screenRecordEntry
        )
      }
    }
  }
}

#Preview("The recording is finished") {
  let recoreonServices = PreviewRecoreonServices()
  recoreonServices.deployAllAssets()

  let screenRecordService = recoreonServices.screenRecordService
  let screenRecordEntries = screenRecordService.listScreenRecordEntries()
  let screenRecordEntry = screenRecordEntries[0]
  let path: NavigationPath = NavigationPath()
  let screenRecordStore = ScreenRecordStore(
    screenRecordService: screenRecordService
  )

  let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults!
  appGroupsUserDefaults.set(
    Date().timeIntervalSince1970 - 10,
    forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey
  )
  appGroupsUserDefaults.set(
    screenRecordEntry.url.absoluteString,
    forKey: AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey
  )

  return ScreenRecordDetailViewContainer(
    recoreonServices: recoreonServices,
    screenRecordStore: screenRecordStore,
    path: path,
    screenRecordEntry: screenRecordEntry
  )
}

#Preview("The recording is ongoing") {
  let recoreonServices = PreviewRecoreonServices()
  recoreonServices.deployAllAssets()

  let screenRecordService = recoreonServices.screenRecordService
  let screenRecordEntries = screenRecordService.listScreenRecordEntries()
  let screenRecordEntry = screenRecordEntries[0]
  let path: NavigationPath = NavigationPath()
  let screenRecordStore = ScreenRecordStore(
    screenRecordService: screenRecordService
  )

  let appGroupsUserDefaults = AppGroupsPreferenceService.userDefaults!
  appGroupsUserDefaults.set(
    Date().timeIntervalSince1970 + 1000,
    forKey: AppGroupsPreferenceService.ongoingRecordingTimestampKey
  )
  appGroupsUserDefaults.set(
    screenRecordEntry.url.absoluteString,
    forKey: AppGroupsPreferenceService.ongoingRecordingURLAbsoluteStringKey
  )

  return ScreenRecordDetailViewContainer(
    recoreonServices: recoreonServices,
    screenRecordStore: screenRecordStore,
    path: path,
    screenRecordEntry: screenRecordEntry
  )
}
#endif

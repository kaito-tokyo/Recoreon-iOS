import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct AdvancedRecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath

  @State private var selection = Set<URL>()
  @State private var storedSelection = Set<URL>()

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    NavigationStack(path: $path) {
      ZStack {
        List(selection: $selection) {
          ForEach(recordedVideoStore.recordedVideoEntries) { entry in
            NavigationLink(
              value: AdvancedRecordedVideoDetailViewRoute(
                recordedVideoEntry: entry
              )
            ) {
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
          }.onDelete { indexSet in
            for index in indexSet {
              let entry = recordedVideoStore.recordedVideoEntries[index]
              recordedVideoService.removeRecordedVideo(recordedVideoEntry: entry)
            }
            recordedVideoStore.update()
          }.onChange(of: scenePhase) { phase in
            if phase == .background {
              storedSelection = selection
            } else if phase == .inactive {
              selection = storedSelection
            }
          }
        }
        HStack {
          Spacer()
          VStack {
            Spacer()
            ShareLink(
              items: Array(selection),
              label: {
                Image(systemName: "square.and.arrow.up")
                  .resizable()
                  .scaledToFill()
                  .frame(width: 32, height: 32)
                  .tint(Color.white)
                  .padding(.all, 20)
                  .background(selection.isEmpty ? Color.gray : Color.blue)
                  .clipShape(Circle())
              }
            )
            .disabled(selection.isEmpty)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
          }
        }
      }
      .navigationTitle("List")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(for: AdvancedRecordedVideoDetailViewRoute.self) { route in
        AdvancedRecordedVideoDetailView(
          recordedVideoService: recordedVideoService,
          recordedVideoStore: recordedVideoStore,
          path: $path,
          recordedVideoEntry: route.recordedVideoEntry
        )
      }
      .toolbar {
        EditButton()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()
    @State var path = NavigationPath()
    @StateObject var store = RecordedVideoStore(recordedVideoService: service)

    return NavigationStack {
      AdvancedRecordedVideoListView(
        recordedVideoService: service,
        recordedVideoStore: store,
        path: $path
      )
    }
  }
#endif

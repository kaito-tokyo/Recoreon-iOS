import AVKit
import ReplayKit
import SwiftUI

let byteCountFormatter = {
  let bcf = ByteCountFormatter()
  bcf.allowedUnits = [.useMB, .useGB]
  return bcf
}()

struct RecordedVideoListView: View {
  let recordedVideoService: RecordedVideoService
  @ObservedObject var recordedVideoStore: RecordedVideoStore
  @Binding var path: NavigationPath

  @State var selection = Set<URL>()

  var body: some View {
    ZStack {
      List(selection: $selection) {
        ForEach(recordedVideoStore.recordedVideoEntries) { entry in
          NavigationLink(
            value: RecordedVideoDetailViewRoute(
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
    .navigationDestination(for: RecordedVideoDetailViewRoute.self) { route in
      RecordedVideoDetailView(
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

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    @State var entries = service.listRecordedVideoEntries()
    @State var path = NavigationPath()
    @StateObject var store = RecordedVideoStore(recordedVideoService: service)

    return NavigationStack {
      RecordedVideoListView(
        recordedVideoService: service,
        recordedVideoStore: store,
        path: $path
      )
    }
  }
#endif
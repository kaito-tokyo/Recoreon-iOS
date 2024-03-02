import ReplayKit
import SwiftUI

struct ContentView: View {
  let recoreonServices: RecoreonServices

  @StateObject var screenRecordStore: ScreenRecordStore

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView {
      ScreenRecordView(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore
      )
      .tabItem { Image(systemName: "list.bullet") }
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        screenRecordStore.update()
      }
    }
  }
}

#if DEBUG
  #Preview {
    let recoreonServices = PreviewRecoreonServices()

    return ContentView(
      recoreonServices: recoreonServices,
      screenRecordStore: ScreenRecordStore(
        screenRecordService: recoreonServices.screenRecordService
      )
    )
  }
#endif

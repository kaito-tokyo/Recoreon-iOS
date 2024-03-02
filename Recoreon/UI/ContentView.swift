import ReplayKit
import SwiftUI

struct ContentView: View {
  let recoreonServices: RecoreonServices

  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    TabView {
      ScreenRecordView(recoreonServices: recoreonServices)
        .tabItem { Image(systemName: "list.bullet") }
      RecorderView()
        .tabItem { Image(systemName: "record.circle") }
    }
  }
}

#if DEBUG
  #Preview {
    ContentView(recoreonServices: PreviewRecoreonServices())
  }
#endif

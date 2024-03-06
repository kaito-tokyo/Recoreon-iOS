import ReplayKit
import SwiftUI

struct ContentView: View {
  let recoreonServices: RecoreonServices

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
    let recoreonServices = PreviewRecoreonServices()
    recoreonServices.deployAllAssets()
    return ContentView(recoreonServices: recoreonServices)
  }
#endif

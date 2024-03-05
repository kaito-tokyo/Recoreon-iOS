import SwiftUI

struct ScreenRecordView: View {
  let recoreonServices: RecoreonServices
  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      ScreenRecordListView(
        recoreonServices: recoreonServices,
        path: $path
      )
    }
  }
}

#if DEBUG
  #Preview {
    ScreenRecordView(
      recoreonServices: PreviewRecoreonServices()
    )
  }
#endif

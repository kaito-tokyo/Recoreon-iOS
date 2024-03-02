import SwiftUI

struct ScreenRecordView: View {
  let recoreonServices: RecoreonServices
  @ObservedObject var screenRecordStore: ScreenRecordStore

  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      ScreenRecordListView(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore,
        path: $path
      )
    }
  }
}

import SwiftUI

struct ScreenRecordView: View {
  @ObservedObject var recoreonServiceStore: RecoreonServiceStore
  @StateObject var screenRecordStore: ScreenRecordStore
  @State var path = NavigationPath()

  init(recoreonServiceStore: RecoreonServiceStore) {
    self.recoreonServiceStore = recoreonServiceStore
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServiceStore.screenRecordService)
    _screenRecordStore = StateObject(wrappedValue: screenRecordStore)
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScreenRecordListView(
        recoreonServiceStore: recoreonServiceStore,
        screenRecordStore: screenRecordStore,
        path: $path
      )
    }
  }
}

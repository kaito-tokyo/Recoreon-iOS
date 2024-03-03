import SwiftUI

struct ScreenRecordView: View {
  let recoreonServices: RecoreonServices
  @StateObject var screenRecordStore: ScreenRecordStore
  @State var path = NavigationPath()

  @Environment(\.scenePhase) private var scenePhase

  init(recoreonServices: RecoreonServices) {
    self.recoreonServices = recoreonServices
    let screenRecordStore = ScreenRecordStore(
      screenRecordService: recoreonServices.screenRecordService
    )
    _screenRecordStore = StateObject(wrappedValue: screenRecordStore)
  }

  var body: some View {
    NavigationStack(path: $path) {
      ScreenRecordListView(
        recoreonServices: recoreonServices,
        screenRecordStore: screenRecordStore,
        path: $path
      )
      .onChange(of: scenePhase) { newValue in
        if newValue == .active {
          screenRecordStore.update()
        }
      }
    }
  }
}

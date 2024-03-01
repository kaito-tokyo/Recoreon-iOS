import SwiftUI

struct ScreenRecordView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore

  @State var path = NavigationPath()

  var body: some View {
    NavigationStack(path: $path) {
      ScreenRecordListView(
        screenRecordService: screenRecordService,
        screenRecordStore: screenRecordStore,
        path: $path
      )
    }
  }
}

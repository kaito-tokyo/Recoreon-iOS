import SwiftUI

struct ScreenRecordView: View {
  let screenRecordService: ScreenRecordService
  @ObservedObject var screenRecordStore: ScreenRecordStore

  @State var path = NavigationPath()

  var body: some View {
    let recordNoteService = screenRecordService.createRecordNoteService()
    NavigationStack(path: $path) {
      ScreenRecordListView(
        screenRecordService: screenRecordService,
        recordNoteService: recordNoteService,
        screenRecordStore: screenRecordStore,
        path: $path
      )
    }
  }
}

import SwiftUI

class ScreenRecordStore: ObservableObject {
  private let screenRecordService: ScreenRecordService

  @Published var screenRecordEntries: [ScreenRecordEntry] = []

  init(screenRecordService: ScreenRecordService) {
    self.screenRecordService = screenRecordService
    update()
  }

  func update() {
    screenRecordEntries = screenRecordService.listScreenRecordEntries()
  }
}

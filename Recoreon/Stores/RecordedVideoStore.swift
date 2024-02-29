import SwiftUI

class RecordedVideoStore: ObservableObject {
  private let recordedVideoService: RecordedVideoService

  @Published var recordedVideoEntries: [RecordedVideoEntry] = []

  init(recordedVideoService: RecordedVideoService) {
    self.recordedVideoService = recordedVideoService
    update()
  }

  func update() {
    recordedVideoEntries = recordedVideoService.listRecordedVideoEntries()
  }
}

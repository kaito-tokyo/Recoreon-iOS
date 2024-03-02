class RecoreonServiceStore: ObservableObject {
  @Published var recoreonPathService: RecoreonPathService
  @Published var encodeService: EncodeService
  @Published var recordNoteService: RecordNoteService
  @Published var screenRecordService: ScreenRecordService

  init(
    recoreonPathService: RecoreonPathService,
    encodeService: EncodeService,
    recordNoteService: RecordNoteService,
    screenRecordService: ScreenRecordService
  ) {
    self.recoreonPathService = recoreonPathService
    self.encodeService = encodeService
    self.recordNoteService = recordNoteService
    self.screenRecordService = screenRecordService
  }
}

class RecordNoteServiceMock: RecordNoteService {
  init() {
    super.init(RecoreonPathService(FileManager.default))
  }
}

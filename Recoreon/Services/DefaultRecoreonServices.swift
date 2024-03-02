struct DefaultRecoreonServices: RecoreonServices {
  let recoreonPathService: RecoreonPathService
  let screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = DefaultRecoreonPathService(fileManager: fileManager)

    self.recoreonPathService = recoreonPathService
    screenRecordService = DefaultScreenRecordService(fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}

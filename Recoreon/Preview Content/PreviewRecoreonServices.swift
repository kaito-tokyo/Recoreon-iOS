struct PreviewRecoreonServices: RecoreonServices {
  let recoreonPathService: RecoreonPathService
  var screenRecordService: ScreenRecordService

  init() {
    let fileManager = FileManager.default
    let recoreonPathService = DefaultRecoreonPathService(fileManager: fileManager)

    self.recoreonPathService = recoreonPathService
    screenRecordService = PreviewScreenRecordService(fileManager: fileManager, recoreonPathService: recoreonPathService)
  }
}

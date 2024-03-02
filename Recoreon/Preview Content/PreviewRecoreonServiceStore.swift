let previewRecoreonServiceStore = {
  let fileManager = FileManager.default
  let recoreonPathService = DefaultRecoreonPathService(fileManager: fileManager)

  let encodeService = PreviewEncodeService(
    fileManager: fileManager, recoreonPathService: recoreonPathService)
  let recordNoteService = PreviewRecordNoteService(recoreonPathService: recoreonPathService)
  let screenRecordService = PreviewScreenRecordService(
    fileManager: fileManager, recoreonPathService: recoreonPathService)
  let recoreonServiceStore = RecoreonServiceStore(
    recoreonPathService: recoreonPathService,
    encodeService: encodeService,
    recordNoteService: recordNoteService,
    screenRecordService: screenRecordService
  )
  return recoreonServiceStore
}()

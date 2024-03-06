import SwiftUI

struct ScreenRecordEncoderViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordEncoderView: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  @State private var encodingPreset: EncodingPreset = .lowQuality
  @State private var encodingProgress: Double = 0.0
  @State private var encodedVideoEntry: EncodedVideoEntry?

  let encodeService: EncodeService

  init(
    recoreonServices: RecoreonServices,
    screenRecordEntry: ScreenRecordEntry
  ) {
    self.recoreonServices = recoreonServices
    self.screenRecordEntry = screenRecordEntry
    encodeService = recoreonServices.encodeService
  }

  func encode() async -> EncodedVideoEntry? {
    encodedVideoEntry = nil
    return await encodeService.encode(
      screenRecordEntry: screenRecordEntry,
      preset: encodingPreset,
      progressHandler: { currentTime, totalTime in
        encodingProgress = min(currentTime / totalTime, 1.0)
      }
    )
  }

  var body: some View {
    Form {
      Section(header: Text("Encoding settings")) {
        Picker("Preset", selection: $encodingPreset) {
          Text("Low Quality").tag(EncodingPreset.lowQuality)
          Text("2x Speed Low Quality").tag(EncodingPreset.twoTimeSpeedLowQuality)
          Text("4x Speed Low Quality").tag(EncodingPreset.fourTimeSpeedLowQuality)
        }
      }
      Section(header: Text("Encoder operations")) {
        Button {
          Task {
            encodedVideoEntry = await encode()
          }
        } label: {
          Label("Encode", systemImage: "film")
        }

        ProgressView("Encoding progress", value: encodingProgress)

        ShareLink(item: encodedVideoEntry?.url ?? URL(string: "invalid")!)
          .disabled(encodedVideoEntry == nil)
      }
    }
  }
}

#if DEBUG
struct ScreenRecordEncoderViewContainer: View {
  let recoreonServices: RecoreonServices
  let screenRecordEntry: ScreenRecordEntry

  var body: some View {
    TabView {
      NavigationStack {
        ScreenRecordEncoderView(
          recoreonServices: recoreonServices,
          screenRecordEntry: screenRecordEntry
        )
      }
    }
  }
}

#Preview {
  let recoreonServices = PreviewRecoreonServices()
  recoreonServices.deployAllAssets()
  let screenRecordService = recoreonServices.screenRecordService
  let screenRecordEntries = screenRecordService.listScreenRecordEntries()
  let screenRecordEntry = screenRecordEntries[0]

  return ScreenRecordEncoderViewContainer(
    recoreonServices: recoreonServices,
    screenRecordEntry: screenRecordEntry
  )
}
#endif

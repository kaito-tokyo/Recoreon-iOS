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

  func encode() async -> EncodedVideoEntry? {
    encodedVideoEntry = nil
    return await recoreonServices.encodeService.encode(
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
  #Preview {
    let recoreonServices = PreviewRecoreonServices()
    let screenRecordService = recoreonServices.screenRecordService
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    return ScreenRecordEncoderView(
      recoreonServices: recoreonServices,
      screenRecordEntry: screenRecordEntry
    )
  }
#endif

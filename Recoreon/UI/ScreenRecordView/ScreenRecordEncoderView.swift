import SwiftUI

struct ScreenRecordEncoderViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordEncoderView: View {
  let encodeService: EncodeService
  let screenRecordEntry: ScreenRecordEntry

  @State private var encodingPreset: EncodingPreset = .lowQuality
  @State private var encodingProgress: Double = 0.0
  @State private var encodedVideoURL: URL?
  @State var encodedVideoEntry: EncodedVideoEntry = .invalid

  var body: some View {
    VStack {
      Form {
        Picker("Preset", selection: $encodingPreset) {
          Text("Low Quality").tag(EncodingPreset.lowQuality)
          Text("2x Speed Low Quality").tag(EncodingPreset.twoTimeSpeedLowQuality)
          Text("4x Speed Low Quality").tag(EncodingPreset.fourTimeSpeedLowQuality)
        }
        .onChange(of: encodingPreset) { value in
          let encodedVideoURL = encodeService.generateEncodedVideoURL(
            screenRecordEntry: screenRecordEntry, preset: encodingPreset)
          encodedVideoEntry = EncodedVideoEntry(
            url: encodedVideoURL,
            preset: value)
        }
      }
      List {
        Button {
          Task {
            guard
              let url = await encodeService.encode(
                screenRecordEntry: screenRecordEntry,
                preset: encodingPreset,
                progressHandler: { currentTime, totalTime in
                  encodingProgress = min(currentTime / totalTime, 1.0)
                }
              )
            else { return }
            encodedVideoURL = url
          }
        } label: {
          Label("Encode", systemImage: "film")
        }
        ProgressView("Encoding progress", value: encodingProgress)
        if let url = encodedVideoURL {
          ShareLink(item: url)
        } else {
          ShareLink(item: "").disabled(true)
        }
        Button {
          encodeService.removeEncodedVideo(encodedVideoEntry: encodedVideoEntry)
        } label: {
          Label("Remove", systemImage: "trash")
        }.disabled(encodedVideoURL == nil)
      }
    }
  }
}

#if DEBUG
  #Preview {
    let screenRecordService = ScreenRecordServiceMock()
    let encodeService = screenRecordService.createEncodeService()
    let screenRecordEntries = screenRecordService.listScreenRecordEntries()
    let screenRecordEntry = screenRecordEntries[0]

    return ScreenRecordEncoderView(
      encodeService: encodeService, screenRecordEntry: screenRecordEntry)
  }
#endif

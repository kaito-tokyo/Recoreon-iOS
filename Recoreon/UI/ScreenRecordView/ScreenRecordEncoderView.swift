import SwiftUI

struct ScreenRecordEncoderViewRoute: Hashable {
  let screenRecordEntry: ScreenRecordEntry
}

struct ScreenRecordEncoderView: View {
  let screenRecordService: ScreenRecordService
  let screenRecordEntry: ScreenRecordEntry

  @State private var encodingPreset: EncodingPreset = .lowQuality
  @State private var encodingProgress: Double = 0.0
  @State private var encodedVideoURL: URL?

  var body: some View {
    Text("Encoder")
    //    VStack {
    //      Form {
    //        Picker("Preset", selection: $encodingPreset) {
    //          Text("Low Quality").tag(EncodingPreset.lowQuality)
    //          Text("2x Speed Low Quality").tag(EncodingPreset.twoTimeSpeedLowQuality)
    //          Text("4x Speed Low Quality").tag(EncodingPreset.fourTimeSpeedLowQuality)
    //        }
    //        .onChange(of: encodingPreset) { value in
    //          encodedVideoURL = screenRecordService.getEncodedVideoURL(
    //            screenRecordURL: screenRecordEntry.url,
    //            encodingPreset: value
    //          )
    //        }
    //      }
    //      List {
    //        Button {
    //          Task {
    //            guard
    //              let url = await screenRecordService.encode(
    //                preset: encodingPreset,
    //                screenRecordURL: screenRecordEntry.url,
    //                progressHandler: { currentTime, totalTime in
    //                  encodingProgress = min(currentTime / totalTime, 1.0)
    //                }
    //              )
    //            else { return }
    //            encodedVideoURL = url
    //          }
    //        } label: {
    //          Label("Encode", systemImage: "film")
    //        }
    //        ProgressView("Encoding progress", value: encodingProgress)
    //        if let url = encodedVideoURL {
    //          ShareLink(item: url)
    //        } else {
    //          ShareLink(item: "").disabled(true)
    //        }
    //        Button {
    //          screenRecordService.removeFileIfExists(url: encodedVideoURL)
    //          encodedVideoURL = nil
    //        } label: {
    //          Label("Remove", systemImage: "trash")
    //        }.disabled(encodedVideoURL == nil)
    //      }
    //    }
  }
}

#if DEBUG
  #Preview {
    let screenRecordService = ScreenRecordServiceMock()
    let screenRecordURLs = screenRecordService.listScreenRecordURLs()
    let screenRecordEntries = screenRecordService.listScreenRecordEntries(
      screenRecordURLs: screenRecordURLs)
    let screenRecordEntry = screenRecordEntries[0]

    return ScreenRecordEncoderView(
      screenRecordService: screenRecordService,
      screenRecordEntry: screenRecordEntry
    )
  }
#endif

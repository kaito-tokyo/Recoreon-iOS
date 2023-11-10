import SwiftUI

struct AdvencedVideoEncoderViewRoute: Hashable {
  let recordedVideoEntry: RecordedVideoEntry
}

struct AdvancedVideoEncoderView: View {
  let recordedVideoService: RecordedVideoService
  @State var recordedVideoEntry: RecordedVideoEntry
  @State var recordedVideoThumbnail: UIImage

  @State private var encodingPreset: EncodingPreset = .lowQuality
  @State private var encodingProgress: Double = 0.0
  @State private var encodedVideoURL: URL?

  var body: some View {
    VStack {
      Image(uiImage: recordedVideoThumbnail).resizable().scaledToFit()
      Form {
        Picker("Preset", selection: $encodingPreset) {
          Text("Low Quality").tag(EncodingPreset.lowQuality)
          Text("2x Speed Low Quality").tag(EncodingPreset.twoTimeSpeedLowQuality)
          Text("4x Speed Low Quality").tag(EncodingPreset.fourTimeSpeedLowQuality)
        }
        .onChange(of: encodingPreset) { value in
          encodedVideoURL = recordedVideoService.getEncodedVideoURL(
            recordedVideoURL: recordedVideoEntry.url,
            encodingPreset: value
          )
        }
      }
      List {
        Button {
          Task {
            guard
              let url = await recordedVideoService.encode(
                preset: encodingPreset,
                recordedVideoURL: recordedVideoEntry.url,
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
          recordedVideoService.removeFileIfExists(url: encodedVideoURL)
          encodedVideoURL = nil
        } label: {
          Label("Remove", systemImage: "trash")
        }.disabled(encodedVideoURL == nil)
      }
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    let entries = service.listRecordedVideoEntries()
    let entry = entries.first!
    let thumbnail = service.getThumbnailImage(entry.url)

    return AdvancedVideoEncoderView(
      recordedVideoService: service,
      recordedVideoEntry: entry,
      recordedVideoThumbnail: thumbnail
    )
  }
#endif

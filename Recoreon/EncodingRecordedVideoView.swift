import SwiftUI

struct EncodingRecordedVideoView: View {
  let recordedVideoService: RecordedVideoService
  @State var entry: RecordedVideoEntry

  @State var encodingProgress: Double = 0
  @State var encodingInProgress: Bool = false
  @State var encodingSuccessfullyPresent: Bool = false
  @State var encodingUnsuccessfullyPresent: Bool = false
  @State var copyToSharedDirSuccessfullyPresent: Bool = false
  @State var copyToSharedDirUnsuccessfullyPresent: Bool = false

  var body: some View {
    VStack {
      if encodingProgress == 0.0 {
        ZStack {
          Image(uiImage: UIImage()).resizable().scaledToFit()
        }.padding()
      } else {
        ZStack {
          Image(uiImage: UIImage()).resizable().scaledToFit().brightness(-0.3)
          ProgressView().scaleEffect(x: 5, y: 5, anchor: .center)
        }.padding()
      }
      HStack {
        Button {
          Task {
            encodingInProgress = true
            guard
              let encodedVideoURL = await recordedVideoService.encode(
                preset: .fourTimeSpeedLowQuality,
                recordedVideoURL: entry.url,
                progressHandler: { currentTime, totalTime in
                  encodingProgress = currentTime / totalTime
                })
            else {
              encodingUnsuccessfullyPresent = true
              encodingInProgress = false
              encodingProgress = 0
              return
            }
            UISaveVideoAtPathToSavedPhotosAlbum(encodedVideoURL.path(), nil, nil, nil)
            encodingInProgress = false
            encodingProgress = 0
            encodingSuccessfullyPresent = true
          }
        } label: {
          Text("Encode")
        }.buttonStyle(.borderedProminent).disabled(encodingInProgress).alert(
          "Encoding completed!", isPresented: $encodingSuccessfullyPresent,
          actions: {
            Button("OK") { encodingSuccessfullyPresent = false }
          }
        ).alert(
          "Encoding failed!", isPresented: $encodingUnsuccessfullyPresent,
          actions: {
            Button("OK") { encodingUnsuccessfullyPresent = false }
          })
        Button {
          let isSucceeded = recordedVideoService.publishRecordedVideo(entry.url)
          if isSucceeded {
            copyToSharedDirSuccessfullyPresent = true
          } else {
            copyToSharedDirUnsuccessfullyPresent = true
          }
        } label: {
          Text("Copy")
        }.buttonStyle(.borderedProminent).disabled(encodingInProgress).alert(
          "The original file of this video was successfully copied to the File app!",
          isPresented: $copyToSharedDirSuccessfullyPresent,
          actions: {
            Button("OK") { copyToSharedDirSuccessfullyPresent = false }
          }
        ).alert(
          "Unable to copy the original file of this video to the File app!",
          isPresented: $copyToSharedDirUnsuccessfullyPresent,
          actions: {
            Button("OK") { copyToSharedDirUnsuccessfullyPresent = false }
          })
      }.padding()
      ProgressView(value: encodingProgress).padding()
    }
  }
}

#if DEBUG
  #Preview {
    let service = RecordedVideoServiceMock()
    let entries = service.listRecordedVideoEntries()
    let entry = entries.first!

    return EncodingRecordedVideoView(
      recordedVideoService: service,
      entry: entry
    )
  }
#endif

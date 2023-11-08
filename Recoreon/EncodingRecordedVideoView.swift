import SwiftUI

struct EncodingRecordedVideoView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol
  @State var encodingEntry: RecordedVideoEntry
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
          Image(uiImage: encodingEntry.uiImage).resizable().scaledToFit()
        }.padding()
      } else {
        ZStack {
          Image(uiImage: encodingEntry.uiImage).resizable().scaledToFit().brightness(-0.3)
          ProgressView().scaleEffect(x: 5, y: 5, anchor: .center)
        }.padding()
      }
      HStack {
        Button {
          Task {
            encodingInProgress = true
            let isSucceeded = await recordedVideoManipulator.encodeAsync(
              encodingEntry.url,
              progressHandler: {
                encodingProgress = $0
              })
            encodingInProgress = false
            encodingProgress = 0
            if isSucceeded {
              encodingSuccessfullyPresent = true
            } else {
              encodingUnsuccessfullyPresent = true
            }
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
          let isSucceeded = recordedVideoManipulator.publishRecordedVideo(encodingEntry.url)
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

#Preview {
  let uiImage = UIImage(named: "AppIcon")!
  let entry = RecordedVideoEntry(url: URL(fileURLWithPath: "1.mkv"), uiImage: uiImage)

  return EncodingRecordedVideoView(
    recordedVideoManipulator: RecordedVideoManipulatorMock(), encodingEntry: entry)
}

import SwiftUI

struct EncodingRecordedVideoView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol
  @State var encodingEntry: RecordedVideoEntry
  @State var encodingProgress: Double = 0
  @State var encodingSuccessfullyFinishedIsPresent: Bool = false
  @State var encodingUnsuccessfullyFinishedIsPresent: Bool = false
  @State var copyToSharedDirSuccessfullyFinishedIsPresent: Bool = false
  @State var copyToSharedDirUnsuccessfullyFinishedIsPresent: Bool = false

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
            let isSucceeded = await recordedVideoManipulator.encodeAsync(
              encodingEntry.url,
              progressHandler: {
                encodingProgress = $0
              })
            encodingProgress = 0
            if isSucceeded {
              encodingSuccessfullyFinishedIsPresent = true
            } else {
              encodingUnsuccessfullyFinishedIsPresent = true
            }
          }
        } label: {
          Text("Encode")
        }.buttonStyle(.borderedProminent).alert(
          "Encoding completed!", isPresented: $encodingSuccessfullyFinishedIsPresent,
          actions: {
            Button("OK") { encodingSuccessfullyFinishedIsPresent = false }
          }
        ).alert(
          "Encoding failed!", isPresented: $encodingUnsuccessfullyFinishedIsPresent,
          actions: {
            Button("OK") { encodingUnsuccessfullyFinishedIsPresent = false }
          })
        Button {
          recordedVideoManipulator.publishRecordedVideo(encodingEntry.url)
        } label: {
          Text("Copy")
        }.buttonStyle(.borderedProminent).alert(
          "The original file of this video was successfully copied to the File app!",
          isPresented: $copyToSharedDirSuccessfullyFinishedIsPresent,
          actions: {
            Button("OK") { copyToSharedDirSuccessfullyFinishedIsPresent = false }
          }
        ).alert(
          "Unable to copy the original file of this video to the File app!",
          isPresented: $copyToSharedDirUnsuccessfullyFinishedIsPresent,
          actions: {
            Button("OK") { copyToSharedDirUnsuccessfullyFinishedIsPresent = false }
          })
      }.padding()
      ProgressView(value: encodingProgress).padding()
    }
  }
}

#Preview {
  let uiImage = UIImage(named: "AppIcon")!
  let entry = RecordedVideoEntry(url: URL(fileURLWithPath: "1.mkv"), uiImage: uiImage)

  class RecordedVideoManipulatorMock: RecordedVideoManipulatorProtocol {
    var finishSucessfully = false

    func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async
      -> Bool
    {
      progressHandler(0.3)
      sleep(1)
      progressHandler(0.5)
      sleep(1)
      progressHandler(0.7)
      sleep(1)
      progressHandler(1.1)
      sleep(1)
      finishSucessfully.toggle()
      return finishSucessfully
    }

    func publishRecordedVideo(_ recordedVideoURL: URL) -> Bool {
      finishSucessfully.toggle()
      return finishSucessfully
    }
  }

  return EncodingRecordedVideoView(
    recordedVideoManipulator: RecordedVideoManipulatorMock(), encodingEntry: entry)
}

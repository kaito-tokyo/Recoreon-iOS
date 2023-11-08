import SwiftUI

struct EncodingRecordedVideoView: View {
  let recordedVideoManipulator: RecordedVideoManipulatorProtocol
  @State var encodingEntry: RecordedVideoEntry
  @State var encodingProgress: Double = 0

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
          encodingProgress = 0.5
        } label: {
          Text("Encode")
        }.buttonStyle(.borderedProminent)
        Button {
          encodingProgress = 0.7
        } label: {
          Text("Copy")
        }.buttonStyle(.borderedProminent)
        Button {
          encodingProgress = 0.0
        } label: {
          Text("Cancel")
        }.buttonStyle(.borderedProminent)
      }.padding()
      ProgressView(value: encodingProgress).padding()
    }
  }
}

#Preview {
  let uiImage = UIImage(named: "AppIcon")!
  let entry = RecordedVideoEntry(url: URL(fileURLWithPath: "1.mkv"), uiImage: uiImage)

  class RecordedVideoManipulatorMock: RecordedVideoManipulatorProtocol {
    func encodeAsync(_ recordedVideoURL: URL, progressHandler: @escaping (Double) -> Void) async -> Bool {
      return true
    }

    func publishRecordedVideo(_ recordedVideoURL: URL) {

    }
  }

  return EncodingRecordedVideoView(recordedVideoManipulator: RecordedVideoManipulatorMock(), encodingEntry: entry)
}

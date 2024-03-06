import ReplayKit
import SwiftUI

struct RecorderView: View {
  var body: some View {
    VStack {
      RecoreonBroadcastPickerRepresentable()
    }
  }
}

#if DEBUG
#Preview {
  RecorderView()
}
#endif

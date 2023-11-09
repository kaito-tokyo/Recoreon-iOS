import SwiftUI
import ReplayKit

struct RecoreonBroadcastPickerRepresentable: UIViewRepresentable {
  func getButtonImage(size: Int = 100) -> UIImage? {
    let sizeConfig = UIImage.SymbolConfiguration(pointSize: 100)
    return UIImage(systemName: "record.circle", withConfiguration: sizeConfig)?.withTintColor(.white, renderingMode: .alwaysOriginal)
  }

  func makeUIView(context: Context) -> some UIView {
    let picker = RPSystemBroadcastPickerView()
    picker.preferredExtension = "com.github.umireon.Recoreon.RecoreonBroadcastUploadExtension"
    picker.showsMicrophoneButton = true
    if let button = picker.subviews.first as? UIButton {
      button.frame = CGRect(origin: .zero, size: picker.bounds.size)
      button.layer.cornerRadius = 10
      button.backgroundColor = .systemRed
      button.setImage(getButtonImage(), for: .normal)
    }
    return picker
  }

  func updateUIView(_ uiView: UIViewType, context: Context) {
  }
}

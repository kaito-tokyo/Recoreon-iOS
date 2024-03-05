import Foundation

public struct AppGroupsPreferenceService {
  public static let userDefaults = UserDefaults(suiteName: appGroupsIdentifier)

  public static let ongoingRecordingTimestampKey = "ongoingRecordingTimestamp"
  public static let ongoingRecordingURLAbsoluteStringKey = "ongoingRecordingURLAbsoluteString"

  public init() {
  }

  public func isRecordingOngoing(
    screenRecordURL: URL,
    ongoingRecordingTimestamp: Double,
    ongoingRecordingURLAbsoluteString: String
  ) -> Bool {
    let now = Date().timeIntervalSince1970
    if now - ongoingRecordingTimestamp < 5 {
      return screenRecordURL.absoluteString == ongoingRecordingURLAbsoluteString
    } else {
      return false
    }
  }
}

import Foundation

public struct AppGroupsPreferenceService {
  public init() {
  }

  public static let userDefaults = UserDefaults(suiteName: appGroupsIdentifier)

  public static let isRecordingKey = "isRecording"
  public static let isRecordingTimestampKey = "isRecordingTimestamp"
  public static let recordingURLKey = "recordingURL"
}

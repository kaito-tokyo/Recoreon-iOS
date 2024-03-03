import Foundation

public struct AppGroupsPreferenceService {
  public init() {
  }

  public static let userDefaults = UserDefaults(suiteName: appGroupsIdentifier)

  public static let isRecordingKey = "isRecording"
  public var isRecording: Bool {
    get { Self.userDefaults?.bool(forKey: Self.isRecordingKey) ?? false }
    set { Self.userDefaults?.set(newValue, forKey: Self.isRecordingKey) }
  }

  public static let isRecordingTimestampKey = "isRecordingTimestamp"
  public var isRecordingTimestamp: Date {
    get { Self.userDefaults?.object(forKey: Self.isRecordingTimestampKey) as? Date ?? Date(timeIntervalSince1970: 0) }
    set { Self.userDefaults?.set(newValue, forKey: Self.isRecordingTimestampKey) }
  }

  public static let recordingURLKey = "recordingURL"
  public var recordingURL: URL? {
    get { Self.userDefaults?.object(forKey: Self.recordingURLKey) as? URL }
    set { Self.userDefaults?.set(newValue?.absoluteString, forKey: Self.recordingURLKey) }
  }
}

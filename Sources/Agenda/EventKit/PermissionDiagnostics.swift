import EventKit
import Foundation

/// EventKit authorization status names reported by Agenda.
///
/// These match `EKAuthorizationStatus` case names. `.authorized` is the
/// deprecated pre-macOS 14 name. On the macOS 14 SDK it may share a raw value
/// with `.fullAccess`; when it does, `AuthorizationStatusName.init(eventKit:)`
/// reports `fullAccess`, because that is the name the current SDK uses for
/// that value. `.unknown` is reserved for a status this version of the SDK
/// does not name.
public enum AuthorizationStatusName: String, Sendable, Equatable, Encodable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
    case authorized
    case unknown

    /// Raw value of `EKAuthorizationStatusAuthorized` in EKTypes.h.
    ///
    /// The original enum is `notDetermined = 0`, then `restricted`, `denied`,
    /// and `authorized`. The macOS 14 SDK deprecates that case. When its raw
    /// value is also `fullAccess`, this mapper reports `fullAccess` and does
    /// not name the deprecated case.
    private static let legacyAuthorizedRawValue = 3

    /// Maps an EventKit status without collapsing distinct cases.
    ///
    /// `fullAccess` is checked before the legacy raw value because those can
    /// alias. The deprecated case is not named here; naming it warns on the
    /// macOS 14 SDK, and a switch cannot list both when they share a raw value.
    public init(eventKit status: EKAuthorizationStatus) {
        if status == .notDetermined {
            self = .notDetermined
        } else if status == .restricted {
            self = .restricted
        } else if status == .denied {
            self = .denied
        } else if status == .writeOnly {
            self = .writeOnly
        } else if status == .fullAccess {
            self = .fullAccess
        } else if status.rawValue == Self.legacyAuthorizedRawValue,
                  Self.legacyAuthorizedRawValue != EKAuthorizationStatus.fullAccess.rawValue {
            self = .authorized
        } else {
            self = .unknown
        }
    }

    /// Full-access requests are only meaningful before the user or a policy
    /// has recorded a decision. Calling them for any other status does not
    /// show a new prompt.
    public static func shouldAttemptFullAccessRequest(_ status: AuthorizationStatusName) -> Bool {
        switch status {
        case .notDetermined:
            return true
        case .restricted, .denied, .fullAccess, .writeOnly, .authorized, .unknown:
            return false
        }
    }

    /// Whether reminder tools can proceed. Matches `requestRemindersAccess`:
    /// full access, the legacy authorized status, and write-only all pass.
    public var allowsRemindersUse: Bool {
        switch self {
        case .fullAccess, .authorized, .writeOnly:
            return true
        case .notDetermined, .restricted, .denied, .unknown:
            return false
        }
    }

    /// Whether calendar tools can read and write events. Matches
    /// `requestCalendarAccess`: write-only is not enough.
    public var allowsCalendarUse: Bool {
        switch self {
        case .fullAccess, .authorized:
            return true
        case .notDetermined, .restricted, .denied, .writeOnly, .unknown:
            return false
        }
    }
}

/// Domain and code from a failed `requestFullAccess` call.
///
/// `userInfo` is not copied. Localized text is kept only on this value so it
/// can be returned in the diagnostic JSON. Stderr logging uses `domain` and
/// `code` alone.
public struct PermissionRequestError: Sendable, Equatable, Encodable {
    public let domain: String
    public let code: Int
    public let description: String

    public init(domain: String, code: Int, description: String) {
        self.domain = domain
        self.code = code
        self.description = description
    }

    public init(_ error: Error) {
        let nsError = error as NSError
        self.domain = nsError.domain
        self.code = nsError.code
        self.description = nsError.localizedDescription
    }
}

/// Authorization state for one EventKit entity, plus the outcome of a
/// full-access request when one was made.
///
/// `status` is the `EKAuthorizationStatus` read after a request when one was
/// attempted, and the current status otherwise. It is not rewritten when a
/// request returns false or throws. `requestGranted` and `requestError` are
/// the request's own result, separate from `status`.
public struct EntityPermissionReport: Sendable, Equatable, Encodable {
    public let status: AuthorizationStatusName
    /// `EKAuthorizationStatus.rawValue` for `status`.
    public let statusRawValue: Int
    public let requestAttempted: Bool
    /// The `Bool` returned by `requestFullAccess*`, when the call returned.
    /// `nil` when no request was made or the call threw.
    public let requestGranted: Bool?
    public let requestError: PermissionRequestError?

    public init(
        status: AuthorizationStatusName,
        statusRawValue: Int,
        requestAttempted: Bool,
        requestGranted: Bool?,
        requestError: PermissionRequestError?
    ) {
        self.status = status
        self.statusRawValue = statusRawValue
        self.requestAttempted = requestAttempted
        self.requestGranted = requestGranted
        self.requestError = requestError
    }

    public static func notAttempted(
        status: AuthorizationStatusName,
        rawValue: Int
    ) -> EntityPermissionReport {
        EntityPermissionReport(
            status: status,
            statusRawValue: rawValue,
            requestAttempted: false,
            requestGranted: nil,
            requestError: nil
        )
    }

    public static func afterReturn(
        granted: Bool,
        status: AuthorizationStatusName,
        rawValue: Int
    ) -> EntityPermissionReport {
        EntityPermissionReport(
            status: status,
            statusRawValue: rawValue,
            requestAttempted: true,
            requestGranted: granted,
            requestError: nil
        )
    }

    public static func afterFailure(
        error: PermissionRequestError,
        status: AuthorizationStatusName,
        rawValue: Int
    ) -> EntityPermissionReport {
        EntityPermissionReport(
            status: status,
            statusRawValue: rawValue,
            requestAttempted: true,
            requestGranted: nil,
            requestError: error
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(statusRawValue, forKey: .statusRawValue)
        try container.encode(requestAttempted, forKey: .requestAttempted)
        if let requestGranted {
            try container.encode(requestGranted, forKey: .requestGranted)
        } else {
            try container.encodeNil(forKey: .requestGranted)
        }
        if let requestError {
            try container.encode(requestError, forKey: .requestError)
        } else {
            try container.encodeNil(forKey: .requestError)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case status
        case statusRawValue
        case requestAttempted
        case requestGranted
        case requestError
    }
}

/// Reminders and Calendar diagnostics from one check.
///
/// This value does not include calendar or reminder titles. Building it only
/// reads authorization status and, when that status is `notDetermined`, the
/// result of the full-access request.
public struct PermissionDiagnostic: Sendable, Equatable, Encodable {
    public let reminders: EntityPermissionReport
    public let calendar: EntityPermissionReport
    public let allGranted: Bool
    /// Present when access is not granted. Explains the reported statuses.
    /// `nil` when both entities allow use.
    public let help: String?

    public init(reminders: EntityPermissionReport, calendar: EntityPermissionReport) {
        self.reminders = reminders
        self.calendar = calendar
        self.allGranted = reminders.status.allowsRemindersUse && calendar.status.allowsCalendarUse
        self.help = PermissionDiagnosticHelp.make(reminders: reminders, calendar: calendar)
    }

    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    public func toJSONValue() throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: jsonData())
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(reminders, forKey: .reminders)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(allGranted, forKey: .allGranted)
        if let help {
            try container.encode(help, forKey: .help)
        } else {
            try container.encodeNil(forKey: .help)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case reminders
        case calendar
        case allGranted
        case help
    }
}

/// Help text derived only from the diagnostic fields.
public enum PermissionDiagnosticHelp {
    /// How macOS attributes a command-line tool's privacy prompt.
    public static let settingsNote = """
        Calendar and Reminders prompts for this command-line tool are attributed \
        to the app that launched it. The controls are that app's rows in \
        System Settings → Privacy & Security → Calendars and \
        System Settings → Privacy & Security → Reminders.
        """

    public static func make(
        reminders: EntityPermissionReport,
        calendar: EntityPermissionReport
    ) -> String? {
        let granted = reminders.status.allowsRemindersUse && calendar.status.allowsCalendarUse
        guard !granted else { return nil }
        return [
            describe(entity: "Reminders", report: reminders),
            describe(entity: "Calendar", report: calendar),
            settingsNote
        ].joined(separator: " ")
    }

    static func describe(entity: String, report: EntityPermissionReport) -> String {
        var sentence = "\(entity) status is \(report.status.rawValue)."
        if report.requestAttempted {
            if let granted = report.requestGranted {
                sentence += " A full-access request was attempted and returned \(granted)."
            } else if let error = report.requestError {
                sentence += " A full-access request was attempted and failed with \(error.domain) code \(error.code)."
            } else {
                sentence += " A full-access request was attempted."
            }
        } else {
            sentence += " No full-access request was attempted."
        }
        return sentence
    }
}

/// Stderr text for a failed full-access request.
///
/// The line contains the entity name (`Reminders` or `Calendar`), the error
/// domain, and the error code. It does not contain the localized description
/// or any other `userInfo`, so a title cannot be written to stderr from here.
public enum PermissionDiagnosticsLogging {
    public static func requestFailedLine(entity: String, error: PermissionRequestError) -> String {
        "\(entity) full-access request failed: \(error.domain) \(error.code)"
    }

    /// Placeholder written over `requestError.description` in stderr debug logs.
    public static let redactedDescription = "[redacted]"

    /// Copy of a JSON-RPC response string for stderr.
    ///
    /// The stdout payload is left unchanged. `requestError.description` is
    /// replaced here because `--debug` logs the serialized response, and that
    /// text can contain a calendar or reminder title. Domain and code stay.
    public static func redactRequestErrorDescriptions(in responseJSON: String) -> String {
        guard let data = responseJSON.data(using: .utf8),
              let value = try? JSONDecoder().decode(JSONValue.self, from: data),
              let redacted = encode(redactDescriptions(in: value)) else {
            return responseJSON
        }
        return redacted
    }

    private static func redactDescriptions(in value: JSONValue) -> JSONValue {
        switch value {
        case .null, .bool, .int, .double:
            return value
        case .string(let text):
            return redactEmbeddedJSONString(text)
        case .array(let items):
            return .array(items.map { redactDescriptions(in: $0) })
        case .object(let fields):
            var copy: [String: JSONValue] = [:]
            for (key, nested) in fields {
                copy[key] = redactDescriptions(in: nested)
            }
            if case .object(var errorFields) = copy["requestError"], errorFields["description"] != nil {
                errorFields["description"] = .string(redactedDescription)
                copy["requestError"] = .object(errorFields)
            }
            return .object(copy)
        }
    }

    /// Tool results embed the diagnostic JSON as a string. Redact inside that string.
    private static func redactEmbeddedJSONString(_ text: String) -> JSONValue {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("{") || trimmed.hasPrefix("["),
              let data = text.data(using: .utf8),
              let inner = try? JSONDecoder().decode(JSONValue.self, from: data),
              let redacted = encode(redactDescriptions(in: inner)) else {
            return .string(text)
        }
        return .string(redacted)
    }

    private static func encode(_ value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

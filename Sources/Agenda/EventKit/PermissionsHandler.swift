import Foundation
import EventKit

/// Errors related to EventKit permissions.
public enum PermissionError: Error, LocalizedError {
    case remindersAccessDenied
    case remindersAccessRestricted
    case calendarAccessDenied
    case calendarAccessRestricted
    case fullAccessRequired
    case unknown(Error)

    public var errorDescription: String? {
        switch self {
        case .remindersAccessDenied:
            return "Access to Reminders was denied. Please grant access in System Settings > Privacy & Security > Reminders."
        case .remindersAccessRestricted:
            return "Access to Reminders is restricted by system policy."
        case .calendarAccessDenied:
            return "Access to Calendar was denied. Please grant access in System Settings > Privacy & Security > Calendars."
        case .calendarAccessRestricted:
            return "Access to Calendar is restricted by system policy."
        case .fullAccessRequired:
            return "Full access to Calendar is required for creating and modifying events. Please grant full access in System Settings > Privacy & Security > Calendars."
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }

    /// The JSON-RPC error for this permission error.
    public var jsonRPCError: JSONRPCError {
        .permissionDenied(localizedDescription)
    }
}

/// Handles requesting and checking EventKit permissions.
///
/// This actor provides thread-safe access to the EventKit event store
/// and manages permission requests for both Reminders and Calendar.
public actor PermissionsHandler {
    /// The shared EventKit event store.
    public let eventStore: EKEventStore

    /// Whether reminders access has been granted.
    private var remindersAccessGranted: Bool?

    /// Whether calendar access has been granted.
    private var calendarAccessGranted: Bool?

    /// Creates a new permissions handler.
    public init() {
        self.eventStore = EKEventStore()
    }

    // MARK: - Reminders Permissions

    /// Requests access to Reminders if not already granted.
    ///
    /// - Throws: `PermissionError` if access cannot be obtained.
    public func requestRemindersAccess() async throws {
        // Check if we already know the status
        if let granted = remindersAccessGranted, granted {
            return
        }

        // Check current authorization status
        let status = EKEventStore.authorizationStatus(for: .reminder)

        switch status {
        case .authorized:
            remindersAccessGranted = true
            await Logger.shared.info("Reminders access already authorized")
            return

        case .notDetermined:
            // Request access
            await Logger.shared.info("Requesting Reminders access...")
            let granted = try await eventStore.requestFullAccessToReminders()

            remindersAccessGranted = granted

            if granted {
                await Logger.shared.info("Reminders access granted")
            } else {
                await Logger.shared.warning("Reminders access denied by user")
                throw PermissionError.remindersAccessDenied
            }

        case .denied:
            remindersAccessGranted = false
            throw PermissionError.remindersAccessDenied

        case .restricted:
            remindersAccessGranted = false
            throw PermissionError.remindersAccessRestricted

        case .fullAccess:
            remindersAccessGranted = true
            await Logger.shared.info("Reminders full access already authorized")
            return

        case .writeOnly:
            // Write-only is sufficient for most operations
            remindersAccessGranted = true
            await Logger.shared.info("Reminders write-only access authorized")
            return

        @unknown default:
            await Logger.shared.warning("Unknown reminders authorization status: \(status.rawValue)")
            throw PermissionError.remindersAccessDenied
        }
    }

    /// Checks if Reminders access is currently granted.
    ///
    /// - Returns: True if access is granted.
    public func hasRemindersAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .reminder)
        return AuthorizationStatusName(eventKit: status).allowsRemindersUse
    }

    // MARK: - Calendar Permissions

    /// Requests access to Calendar if not already granted.
    ///
    /// - Throws: `PermissionError` if access cannot be obtained.
    public func requestCalendarAccess() async throws {
        // Check if we already know the status
        if let granted = calendarAccessGranted, granted {
            return
        }

        // Check current authorization status
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .authorized:
            calendarAccessGranted = true
            await Logger.shared.info("Calendar access already authorized")
            return

        case .notDetermined:
            // Request full access for read and write
            await Logger.shared.info("Requesting Calendar access...")
            let granted = try await eventStore.requestFullAccessToEvents()

            calendarAccessGranted = granted

            if granted {
                await Logger.shared.info("Calendar access granted")
            } else {
                await Logger.shared.warning("Calendar access denied by user")
                throw PermissionError.calendarAccessDenied
            }

        case .denied:
            calendarAccessGranted = false
            throw PermissionError.calendarAccessDenied

        case .restricted:
            calendarAccessGranted = false
            throw PermissionError.calendarAccessRestricted

        case .fullAccess:
            calendarAccessGranted = true
            await Logger.shared.info("Calendar full access already authorized")
            return

        case .writeOnly:
            // Write-only is not sufficient for listing events
            calendarAccessGranted = false
            throw PermissionError.fullAccessRequired

        @unknown default:
            await Logger.shared.warning("Unknown calendar authorization status: \(status.rawValue)")
            throw PermissionError.calendarAccessDenied
        }
    }

    /// Checks if Calendar access is currently granted.
    ///
    /// - Returns: True if full access is granted.
    public func hasCalendarAccess() -> Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return AuthorizationStatusName(eventKit: status).allowsCalendarUse
    }

    // MARK: - Combined Permissions

    /// Requests access to both Reminders and Calendar.
    ///
    /// - Throws: `PermissionError` if either access cannot be obtained.
    public func requestAllAccess() async throws {
        // Request both permissions
        var errors: [PermissionError] = []

        do {
            try await requestRemindersAccess()
        } catch let error as PermissionError {
            errors.append(error)
        }

        do {
            try await requestCalendarAccess()
        } catch let error as PermissionError {
            errors.append(error)
        }

        // If both failed, throw the first error
        if let firstError = errors.first {
            throw firstError
        }
    }

    /// Reads EventKit authorization for Reminders and Calendar and, only when
    /// a status is `notDetermined`, calls the matching `requestFullAccess` API.
    ///
    /// Does not list calendars, events, or reminders. The returned status is
    /// the EventKit status, not a collapsed granted/denied flag. A request
    /// that returns `false` or throws stays visible in `requestGranted` or
    /// `requestError` and does not rewrite `status`.
    public func diagnoseAccess() async -> PermissionDiagnostic {
        let reminders = await diagnose(.reminders)
        let calendar = await diagnose(.calendar)
        return PermissionDiagnostic(reminders: reminders, calendar: calendar)
    }

    private enum AccessEntity {
        case reminders
        case calendar

        var logName: String {
            switch self {
            case .reminders:
                return "Reminders"
            case .calendar:
                return "Calendar"
            }
        }

        var eventKitType: EKEntityType {
            switch self {
            case .reminders:
                return .reminder
            case .calendar:
                return .event
            }
        }
    }

    private func diagnose(_ entity: AccessEntity) async -> EntityPermissionReport {
        let before = EKEventStore.authorizationStatus(for: entity.eventKitType)
        let beforeName = AuthorizationStatusName(eventKit: before)
        guard AuthorizationStatusName.shouldAttemptFullAccessRequest(beforeName) else {
            return .notAttempted(status: beforeName, rawValue: before.rawValue)
        }

        await Logger.shared.info("Requesting full access to \(entity.logName)")
        do {
            let granted = try await requestFullAccess(entity)
            let after = EKEventStore.authorizationStatus(for: entity.eventKitType)
            return .afterReturn(
                granted: granted,
                status: AuthorizationStatusName(eventKit: after),
                rawValue: after.rawValue
            )
        } catch {
            let info = PermissionRequestError(error)
            await Logger.shared.warning(
                PermissionDiagnosticsLogging.requestFailedLine(entity: entity.logName, error: info)
            )
            let after = EKEventStore.authorizationStatus(for: entity.eventKitType)
            return .afterFailure(
                error: info,
                status: AuthorizationStatusName(eventKit: after),
                rawValue: after.rawValue
            )
        }
    }

    private func requestFullAccess(_ entity: AccessEntity) async throws -> Bool {
        switch entity {
        case .reminders:
            return try await eventStore.requestFullAccessToReminders()
        case .calendar:
            return try await eventStore.requestFullAccessToEvents()
        }
    }
}

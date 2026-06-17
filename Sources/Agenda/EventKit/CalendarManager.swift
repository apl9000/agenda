import Foundation
import EventKit

/// Errors that can occur during calendar operations.
public enum CalendarError: Error, LocalizedError {
    case eventNotFound(String)
    case calendarNotFound(String)
    case failedToSave(String)
    case failedToDelete(String)
    case invalidData(String)
    case invalidDateRange

    public var errorDescription: String? {
        switch self {
        case .eventNotFound(let id):
            return "Event not found with ID: \(id)"
        case .calendarNotFound(let name):
            return "Calendar not found: \(name)"
        case .failedToSave(let reason):
            return "Failed to save event: \(reason)"
        case .failedToDelete(let reason):
            return "Failed to delete event: \(reason)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        case .invalidDateRange:
            return "Invalid date range: end date must be after start date"
        }
    }

    /// The JSON-RPC error for this calendar error.
    public var jsonRPCError: JSONRPCError {
        switch self {
        case .eventNotFound:
            return .resourceNotFound(localizedDescription)
        case .calendarNotFound:
            return .resourceNotFound(localizedDescription)
        default:
            return .operationFailed(localizedDescription)
        }
    }
}

/// Filter options for listing events.
public struct EventFilter: Sendable {
    /// Filter by specific calendar name.
    public var calendarName: String?

    /// Start date for the search range.
    public var startDate: Date

    /// End date for the search range.
    public var endDate: Date

    /// Maximum number of results.
    public var limit: Int?

    /// Default filter: events for today.
    public static var today: EventFilter {
        let now = Date()
        return EventFilter(
            startDate: now.startOfDay,
            endDate: now.endOfDay
        )
    }

    /// Default filter: events for this week.
    public static var thisWeek: EventFilter {
        let calendar = Calendar.current
        let now = Date()
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek) ?? now

        return EventFilter(
            startDate: startOfWeek,
            endDate: endOfWeek
        )
    }

    public init(
        calendarName: String? = nil,
        startDate: Date = Date(),
        endDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(),
        limit: Int? = nil
    ) {
        self.calendarName = calendarName
        self.startDate = startDate
        self.endDate = endDate
        self.limit = limit
    }
}

/// Manages interactions with Apple Calendar via EventKit.
///
/// This actor provides a clean async/await interface for CRUD operations
/// on calendar events, handling permissions and error mapping.
public actor CalendarManager {
    private let permissions: PermissionsHandler

    /// Creates a new calendar manager.
    ///
    /// - Parameter permissions: The permissions handler to use.
    public init(permissions: PermissionsHandler) {
        self.permissions = permissions
    }

    /// Ensures calendar access before performing an operation.
    private func ensureAccess() async throws {
        try await permissions.requestCalendarAccess()
    }

    /// Gets the event store from the permissions handler.
    private var eventStore: EKEventStore {
        get async { await permissions.eventStore }
    }

    // MARK: - Calendars

    /// Gets all calendars.
    ///
    /// - Returns: Array of calendar info.
    public func getCalendars() async throws -> [(id: String, name: String, color: String)] {
        try await ensureAccess()

        let calendars = await eventStore.calendars(for: .event)
        return calendars.map { calendar in
            (calendar.calendarIdentifier, calendar.title, Self.hexString(from: calendar.cgColor))
        }
    }

    /// Converts a CGColor to a 6-digit hex string (defaults to white).
    private static func hexString(from cgColor: CGColor?) -> String {
        guard let components = cgColor?.components, components.count >= 3 else {
            return "FFFFFF"
        }
        let r = Int((components[0] * 255).rounded())
        let g = Int((components[1] * 255).rounded())
        let b = Int((components[2] * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    /// Gets a calendar by name.
    ///
    /// - Parameter name: The calendar name.
    /// - Returns: The calendar if found.
    public func getCalendar(named name: String) async throws -> EKCalendar? {
        try await ensureAccess()

        let calendars = await eventStore.calendars(for: .event)
        return calendars.first { $0.title.lowercased() == name.lowercased() }
    }

    /// Gets the default calendar for new events.
    ///
    /// - Returns: The default calendar.
    public func getDefaultCalendar() async throws -> EKCalendar? {
        try await ensureAccess()
        return await eventStore.defaultCalendarForNewEvents
    }

    // MARK: - List Events

    /// Lists events with filtering.
    ///
    /// - Parameter filter: The filter options.
    /// - Returns: Array of events matching the filter.
    public func listEvents(filter: EventFilter = .today) async throws -> [Event] {
        try await ensureAccess()

        let store = await eventStore

        // Determine which calendars to search
        var calendars: [EKCalendar]?

        if let calendarName = filter.calendarName {
            guard let calendar = try await getCalendar(named: calendarName) else {
                throw CalendarError.calendarNotFound(calendarName)
            }
            calendars = [calendar]
        }

        // Create predicate
        let predicate = store.predicateForEvents(
            withStart: filter.startDate,
            end: filter.endDate,
            calendars: calendars
        )

        // Fetch events
        var ekEvents = store.events(matching: predicate)

        // Sort by start date
        ekEvents.sort { $0.startDate < $1.startDate }

        // Apply limit
        if let limit = filter.limit, limit > 0 {
            ekEvents = Array(ekEvents.prefix(limit))
        }

        return ekEvents.map { Event.from($0) }
    }

    // MARK: - Get Event

    /// Gets a single event by ID.
    ///
    /// - Parameter id: The event identifier.
    /// - Returns: The event if found.
    public func getEvent(id: String) async throws -> Event {
        try await ensureAccess()

        guard let ekEvent = await eventStore.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound(id)
        }

        return Event.from(ekEvent)
    }

    // MARK: - Create Event

    /// Creates a new calendar event.
    ///
    /// - Parameters:
    ///   - title: The event title.
    ///   - startDate: The start date and time.
    ///   - endDate: The end date and time.
    ///   - isAllDay: Whether this is an all-day event.
    ///   - notes: Optional notes.
    ///   - location: Optional location.
    ///   - calendarName: Optional calendar name (uses default if not specified).
    ///   - url: Optional URL.
    ///   - availability: Availability status.
    /// - Returns: The created event.
    public func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        notes: String? = nil,
        location: String? = nil,
        calendarName: String? = nil,
        url: String? = nil,
        availability: Event.Availability = .busy
    ) async throws -> Event {
        try await ensureAccess()

        // Validate date range
        guard endDate > startDate else {
            throw CalendarError.invalidDateRange
        }

        let store = await eventStore

        // Get the target calendar
        let calendar: EKCalendar
        if let calendarName = calendarName {
            guard let cal = try await getCalendar(named: calendarName) else {
                throw CalendarError.calendarNotFound(calendarName)
            }
            calendar = cal
        } else {
            guard let defaultCalendar = store.defaultCalendarForNewEvents else {
                throw CalendarError.invalidData("No default calendar available")
            }
            calendar = defaultCalendar
        }

        // Create the event
        let ekEvent = EKEvent(eventStore: store)
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.isAllDay = isAllDay
        ekEvent.calendar = calendar
        ekEvent.availability = availability.ekAvailability

        if let notes = notes {
            ekEvent.notes = notes
        }

        if let location = location {
            ekEvent.location = location
        }

        if let urlString = url, let eventURL = URL(string: urlString) {
            ekEvent.url = eventURL
        }

        // Save
        do {
            try store.save(ekEvent, span: .thisEvent)
            await Logger.shared.info("Created event: \(title)")
        } catch {
            await Logger.shared.error("Failed to save event: \(error)")
            throw CalendarError.failedToSave(error.localizedDescription)
        }

        return Event.from(ekEvent)
    }

    // MARK: - Update Event

    /// Updates an existing event.
    ///
    /// - Parameters:
    ///   - id: The event identifier.
    ///   - title: New title (optional).
    ///   - startDate: New start date (optional).
    ///   - endDate: New end date (optional).
    ///   - isAllDay: New all-day setting (optional).
    ///   - notes: New notes (optional).
    ///   - location: New location (optional).
    ///   - url: New URL (optional).
    ///   - availability: New availability (optional).
    /// - Returns: The updated event.
    public func updateEvent(
        id: String,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        isAllDay: Bool? = nil,
        notes: String? = nil,
        location: String? = nil,
        url: String? = nil,
        availability: Event.Availability? = nil
    ) async throws -> Event {
        try await ensureAccess()

        let store = await eventStore

        guard let ekEvent = store.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound(id)
        }

        // Update fields
        if let title = title {
            ekEvent.title = title
        }

        if let startDate = startDate {
            ekEvent.startDate = startDate
        }

        if let endDate = endDate {
            ekEvent.endDate = endDate
        }

        // Validate date range after updates
        if ekEvent.endDate <= ekEvent.startDate {
            throw CalendarError.invalidDateRange
        }

        if let isAllDay = isAllDay {
            ekEvent.isAllDay = isAllDay
        }

        if let notes = notes {
            ekEvent.notes = notes
        }

        if let location = location {
            ekEvent.location = location
        }

        if let urlString = url {
            ekEvent.url = URL(string: urlString)
        }

        if let availability = availability {
            ekEvent.availability = availability.ekAvailability
        }

        // Save
        do {
            try store.save(ekEvent, span: .thisEvent)
            await Logger.shared.info("Updated event: \(ekEvent.title ?? id)")
        } catch {
            await Logger.shared.error("Failed to update event: \(error)")
            throw CalendarError.failedToSave(error.localizedDescription)
        }

        return Event.from(ekEvent)
    }

    // MARK: - Delete Event

    /// Deletes an event.
    ///
    /// - Parameters:
    ///   - id: The event identifier.
    ///   - deleteAllOccurrences: For recurring events, whether to delete all occurrences.
    public func deleteEvent(id: String, deleteAllOccurrences: Bool = false) async throws {
        try await ensureAccess()

        let store = await eventStore

        guard let ekEvent = store.event(withIdentifier: id) else {
            throw CalendarError.eventNotFound(id)
        }

        let span: EKSpan = deleteAllOccurrences ? .futureEvents : .thisEvent

        do {
            try store.remove(ekEvent, span: span)
            await Logger.shared.info("Deleted event: \(ekEvent.title ?? id)")
        } catch {
            await Logger.shared.error("Failed to delete event: \(error)")
            throw CalendarError.failedToDelete(error.localizedDescription)
        }
    }
}

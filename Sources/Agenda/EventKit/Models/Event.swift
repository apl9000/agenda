import Foundation
import EventKit

/// Represents a calendar event with all relevant properties.
///
/// This is the domain model for events, separate from Apple's EKEvent.
/// It provides a clean interface for the MCP tools.
public struct Event: Codable, Sendable, Identifiable {
    /// The unique identifier for the event.
    public let id: String

    /// The title of the event.
    public var title: String

    /// Notes/description for the event.
    public var notes: String?

    /// The location of the event.
    public var location: String?

    /// The start date and time.
    public var startDate: Date

    /// The end date and time.
    public var endDate: Date

    /// Whether this is an all-day event.
    public var isAllDay: Bool

    /// The name of the calendar this event belongs to.
    public var calendarName: String

    /// The identifier of the calendar this event belongs to.
    public var calendarId: String

    /// The URL associated with the event.
    public var url: String?

    /// The availability status during the event.
    public var availability: Availability

    /// The recurrence rules as a human-readable string.
    public var recurrenceRule: String?

    /// Whether this event has attendees.
    public var hasAttendees: Bool

    /// The number of attendees.
    public var attendeeCount: Int

    /// The organizer's name if available.
    public var organizerName: String?

    /// The creation date of the event.
    public let createdDate: Date?

    /// The last modification date.
    public let lastModifiedDate: Date?

    public init(
        id: String,
        title: String,
        notes: String? = nil,
        location: String? = nil,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        calendarName: String,
        calendarId: String,
        url: String? = nil,
        availability: Availability = .busy,
        recurrenceRule: String? = nil,
        hasAttendees: Bool = false,
        attendeeCount: Int = 0,
        organizerName: String? = nil,
        createdDate: Date? = nil,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.location = location
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.calendarName = calendarName
        self.calendarId = calendarId
        self.url = url
        self.availability = availability
        self.recurrenceRule = recurrenceRule
        self.hasAttendees = hasAttendees
        self.attendeeCount = attendeeCount
        self.organizerName = organizerName
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }

    /// Availability status for events.
    public enum Availability: String, Codable, Sendable {
        case busy
        case free
        case tentative
        case unavailable

        public init(from ekAvailability: EKEventAvailability) {
            switch ekAvailability {
            case .busy:
                self = .busy
            case .free:
                self = .free
            case .tentative:
                self = .tentative
            case .unavailable:
                self = .unavailable
            @unknown default:
                self = .busy
            }
        }

        public var ekAvailability: EKEventAvailability {
            switch self {
            case .busy: return .busy
            case .free: return .free
            case .tentative: return .tentative
            case .unavailable: return .unavailable
            }
        }
    }
}

// MARK: - EKEvent Conversion

extension Event {
    /// Creates an Event from an EKEvent.
    ///
    /// - Parameter ekEvent: The EventKit event.
    /// - Returns: An Event instance.
    public static func from(_ ekEvent: EKEvent) -> Event {
        // Format recurrence rule if present
        var recurrenceRule: String?
        if let rules = ekEvent.recurrenceRules, let firstRule = rules.first {
            recurrenceRule = formatRecurrenceRule(firstRule)
        }

        return Event(
            id: ekEvent.eventIdentifier,
            title: ekEvent.title ?? "",
            notes: ekEvent.notes,
            location: ekEvent.location,
            startDate: ekEvent.startDate,
            endDate: ekEvent.endDate,
            isAllDay: ekEvent.isAllDay,
            calendarName: ekEvent.calendar?.title ?? "Unknown",
            calendarId: ekEvent.calendar?.calendarIdentifier ?? "",
            url: ekEvent.url?.absoluteString,
            availability: Availability(from: ekEvent.availability),
            recurrenceRule: recurrenceRule,
            hasAttendees: ekEvent.hasAttendees,
            attendeeCount: ekEvent.attendees?.count ?? 0,
            organizerName: ekEvent.organizer?.name,
            createdDate: ekEvent.creationDate,
            lastModifiedDate: ekEvent.lastModifiedDate
        )
    }

    /// Formats a recurrence rule as a human-readable string.
    private static func formatRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        var parts: [String] = []

        switch rule.frequency {
        case .daily:
            parts.append(rule.interval == 1 ? "Daily" : "Every \(rule.interval) days")
        case .weekly:
            parts.append(rule.interval == 1 ? "Weekly" : "Every \(rule.interval) weeks")
        case .monthly:
            parts.append(rule.interval == 1 ? "Monthly" : "Every \(rule.interval) months")
        case .yearly:
            parts.append(rule.interval == 1 ? "Yearly" : "Every \(rule.interval) years")
        @unknown default:
            parts.append("Custom recurrence")
        }

        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                parts.append("until \(DateHelpers.formatDateOnly(endDate))")
            } else if end.occurrenceCount > 0 {
                parts.append("for \(end.occurrenceCount) occurrences")
            }
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - JSON Encoding for MCP

extension Event {
    /// Converts the event to a dictionary for JSON response.
    public func toDictionary() -> [String: JSONValue] {
        var dict: [String: JSONValue] = [
            "id": .string(id),
            "title": .string(title),
            "startDate": .string(DateHelpers.formatISO8601(startDate)),
            "endDate": .string(DateHelpers.formatISO8601(endDate)),
            "isAllDay": .bool(isAllDay),
            "calendarName": .string(calendarName),
            "calendarId": .string(calendarId),
            "availability": .string(availability.rawValue),
            "hasAttendees": .bool(hasAttendees),
            "attendeeCount": .int(attendeeCount)
        ]

        if let notes = notes {
            dict["notes"] = .string(notes)
        }

        if let location = location {
            dict["location"] = .string(location)
        }

        if let url = url {
            dict["url"] = .string(url)
        }

        if let recurrenceRule = recurrenceRule {
            dict["recurrenceRule"] = .string(recurrenceRule)
        }

        if let organizerName = organizerName {
            dict["organizerName"] = .string(organizerName)
        }

        if let createdDate = createdDate {
            dict["createdDate"] = .string(DateHelpers.formatISO8601(createdDate))
        }

        if let lastModifiedDate = lastModifiedDate {
            dict["lastModifiedDate"] = .string(DateHelpers.formatISO8601(lastModifiedDate))
        }

        return dict
    }

    /// Converts to JSONValue.
    public func toJSONValue() -> JSONValue {
        .object(toDictionary())
    }
}

// MARK: - Duration Helpers

extension Event {
    /// The duration of the event in seconds.
    public var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// The duration formatted as a human-readable string.
    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if isAllDay {
            let days = Int(duration) / 86400 + 1
            return days == 1 ? "All day" : "\(days) days"
        } else if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

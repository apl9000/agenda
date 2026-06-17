import Foundation
import EventKit

/// Represents a reminder with all relevant properties.
///
/// This is the domain model for reminders, separate from Apple's EKReminder.
/// It provides a clean interface for the MCP tools and handles tag extraction.
public struct Reminder: Codable, Sendable, Identifiable {
    /// The unique identifier for the reminder.
    public let id: String

    /// The title of the reminder.
    public var title: String

    /// Notes/description for the reminder.
    public var notes: String?

    /// The due date for the reminder.
    public var dueDate: Date?

    /// Whether the reminder is completed.
    public var isCompleted: Bool

    /// The completion date if completed.
    public var completionDate: Date?

    /// The priority (0 = none, 1 = high, 5 = medium, 9 = low).
    public var priority: Int

    /// The name of the list this reminder belongs to.
    public var listName: String

    /// The identifier of the list this reminder belongs to.
    public var listId: String

    /// Tags extracted from the notes field.
    public var tags: [Tag]

    /// The creation date of the reminder.
    public let createdDate: Date?

    /// The last modification date.
    public let lastModifiedDate: Date?

    public init(
        id: String,
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        completionDate: Date? = nil,
        priority: Int = 0,
        listName: String,
        listId: String,
        tags: [Tag] = [],
        createdDate: Date? = nil,
        lastModifiedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.completionDate = completionDate
        self.priority = priority
        self.listName = listName
        self.listId = listId
        self.tags = tags
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
    }
}

// MARK: - EKReminder Conversion

extension Reminder {
    /// Creates a Reminder from an EKReminder.
    ///
    /// - Parameter ekReminder: The EventKit reminder.
    /// - Returns: A Reminder instance.
    public static func from(_ ekReminder: EKReminder) -> Reminder {
        let notes = ekReminder.notes
        let tags = notes.map { TagParser.extractTags(from: $0) } ?? []

        // Extract due date from alarm or due date components
        var dueDate: Date?
        if let dueDateComponents = ekReminder.dueDateComponents {
            dueDate = Calendar.current.date(from: dueDateComponents)
        }

        return Reminder(
            id: ekReminder.calendarItemIdentifier,
            title: ekReminder.title ?? "",
            notes: notes,
            dueDate: dueDate,
            isCompleted: ekReminder.isCompleted,
            completionDate: ekReminder.completionDate,
            priority: Int(ekReminder.priority),
            listName: ekReminder.calendar?.title ?? "Unknown",
            listId: ekReminder.calendar?.calendarIdentifier ?? "",
            tags: tags,
            createdDate: ekReminder.creationDate,
            lastModifiedDate: ekReminder.lastModifiedDate
        )
    }
}

// MARK: - JSON Encoding for MCP

extension Reminder {
    /// Converts the reminder to a dictionary for JSON response.
    public func toDictionary() -> [String: JSONValue] {
        var dict: [String: JSONValue] = [
            "id": .string(id),
            "title": .string(title),
            "isCompleted": .bool(isCompleted),
            "priority": .int(priority),
            "listName": .string(listName),
            "listId": .string(listId),
            "tags": .array(tags.map { .string($0.name) })
        ]

        // Present notes without the internal #hashtags — the classification is
        // surfaced via the `tags` array, and the user should never see hashtags.
        if let notes = notes {
            let humanNotes = TagParser.removeTags(from: notes)
            if !humanNotes.isEmpty {
                dict["notes"] = .string(humanNotes)
            }
        }

        if let dueDate = dueDate {
            dict["dueDate"] = .string(DateHelpers.formatISO8601(dueDate))
        }

        if let completionDate = completionDate {
            dict["completionDate"] = .string(DateHelpers.formatISO8601(completionDate))
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

// MARK: - Validation

extension Reminder {
    /// Validates the reminder title for actionability.
    ///
    /// Returns warnings if the title appears vague or non-actionable.
    /// This supports the GTD principle of having clear next actions.
    ///
    /// - Returns: An array of warning messages, empty if valid.
    public func validateTitle() -> [String] {
        var warnings: [String] = []

        let lowercased = title.lowercased()

        // Check for vague titles
        let vaguePatterns = [
            "stuff",
            "things",
            "misc",
            "various",
            "etc"
        ]

        for pattern in vaguePatterns {
            if lowercased.contains(pattern) {
                warnings.append("Title contains vague term '\(pattern)'. Consider being more specific.")
            }
        }

        // Check for titles that are too short
        if title.count < 3 {
            warnings.append("Title is very short. Consider adding more context.")
        }

        // Check for missing verb (GTD best practice)
        let startsWithVerb = [
            "call", "email", "send", "write", "create", "make", "buy",
            "schedule", "plan", "review", "update", "fix", "check",
            "research", "find", "get", "pick", "drop", "meet", "attend",
            "complete", "finish", "start", "begin", "draft", "prepare",
            "read", "watch", "listen", "learn", "practice", "organize",
            "clean", "sort", "file", "submit", "apply", "register",
            "book", "reserve", "cancel", "confirm", "follow", "ask"
        ].contains { lowercased.hasPrefix($0) }

        if !startsWithVerb && !lowercased.hasPrefix("@") {
            warnings.append("Consider starting with an action verb (e.g., 'Call', 'Email', 'Review').")
        }

        return warnings
    }
}

// MARK: - Priority Helpers

extension Reminder {
    /// Priority level enumeration.
    public enum PriorityLevel: Int, Sendable {
        case none = 0
        case high = 1
        case medium = 5
        case low = 9

        public var displayName: String {
            switch self {
            case .none: return "None"
            case .high: return "High"
            case .medium: return "Medium"
            case .low: return "Low"
            }
        }
    }

    /// The priority as a PriorityLevel enum.
    public var priorityLevel: PriorityLevel {
        switch priority {
        case 1...4: return .high
        case 5: return .medium
        case 6...9: return .low
        default: return .none
        }
    }
}

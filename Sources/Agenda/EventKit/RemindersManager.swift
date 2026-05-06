import Foundation
import EventKit

/// Errors that can occur during reminder operations.
public enum ReminderError: Error, LocalizedError {
    case reminderNotFound(String)
    case listNotFound(String)
    case failedToSave(String)
    case failedToDelete(String)
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .reminderNotFound(let id):
            return "Reminder not found with ID: \(id)"
        case .listNotFound(let name):
            return "Reminder list not found: \(name)"
        case .failedToSave(let reason):
            return "Failed to save reminder: \(reason)"
        case .failedToDelete(let reason):
            return "Failed to delete reminder: \(reason)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        }
    }

    /// The JSON-RPC error for this reminder error.
    public var jsonRPCError: JSONRPCError {
        switch self {
        case .reminderNotFound:
            return .resourceNotFound(localizedDescription)
        case .listNotFound:
            return .resourceNotFound(localizedDescription)
        default:
            return .operationFailed(localizedDescription)
        }
    }
}

/// Filter options for listing reminders.
public struct ReminderFilter: Sendable {
    /// Filter by specific list name.
    public var listName: String?

    /// Filter by completion status.
    public var isCompleted: Bool?

    /// Filter by tag.
    public var tag: String?

    /// Filter by due date (reminders due before this date).
    public var dueBefore: Date?

    /// Filter by due date (reminders due after this date).
    public var dueAfter: Date?

    /// Maximum number of results.
    public var limit: Int?

    public init(
        listName: String? = nil,
        isCompleted: Bool? = nil,
        tag: String? = nil,
        dueBefore: Date? = nil,
        dueAfter: Date? = nil,
        limit: Int? = nil
    ) {
        self.listName = listName
        self.isCompleted = isCompleted
        self.tag = tag
        self.dueBefore = dueBefore
        self.dueAfter = dueAfter
        self.limit = limit
    }
}

/// Manages interactions with Apple Reminders via EventKit.
///
/// This actor provides a clean async/await interface for CRUD operations
/// on reminders, handling permissions and error mapping.
public actor RemindersManager {
    private let permissions: PermissionsHandler

    /// Creates a new reminders manager.
    ///
    /// - Parameter permissions: The permissions handler to use.
    public init(permissions: PermissionsHandler) {
        self.permissions = permissions
    }

    /// Ensures reminders access before performing an operation.
    private func ensureAccess() async throws {
        try await permissions.requestRemindersAccess()
    }

    /// Gets the event store from the permissions handler.
    private var eventStore: EKEventStore {
        get async { await permissions.eventStore }
    }

    // MARK: - Lists

    /// Gets all reminder lists.
    ///
    /// - Returns: Array of calendar/list info.
    public func getLists() async throws -> [(id: String, name: String)] {
        try await ensureAccess()

        let calendars = await eventStore.calendars(for: .reminder)
        return calendars.map { ($0.calendarIdentifier, $0.title) }
    }

    /// Gets a list by name.
    ///
    /// - Parameter name: The list name.
    /// - Returns: The calendar if found.
    public func getList(named name: String) async throws -> EKCalendar? {
        try await ensureAccess()

        let calendars = await eventStore.calendars(for: .reminder)
        return calendars.first { $0.title.lowercased() == name.lowercased() }
    }

    /// Gets the default reminder list.
    ///
    /// - Returns: The default calendar for reminders.
    public func getDefaultList() async throws -> EKCalendar? {
        try await ensureAccess()
        return await eventStore.defaultCalendarForNewReminders()
    }

    // MARK: - List Reminders

    /// Lists reminders with optional filtering.
    ///
    /// - Parameter filter: The filter options.
    /// - Returns: Array of reminders matching the filter.
    public func listReminders(filter: ReminderFilter = ReminderFilter()) async throws -> [Reminder] {
        try await ensureAccess()

        // Determine which calendars to search
        var calendars: [EKCalendar]?

        if let listName = filter.listName {
            guard let calendar = try await getList(named: listName) else {
                throw ReminderError.listNotFound(listName)
            }
            calendars = [calendar]
        }

        // Create predicate based on filter
        let predicate: NSPredicate

        if let dueBefore = filter.dueBefore, let dueAfter = filter.dueAfter {
            // Use date range predicate
            predicate = await eventStore.predicateForIncompleteReminders(
                withDueDateStarting: dueAfter,
                ending: dueBefore,
                calendars: calendars
            )
        } else if let isCompleted = filter.isCompleted {
            if isCompleted {
                predicate = await eventStore.predicateForCompletedReminders(
                    withCompletionDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            } else {
                predicate = await eventStore.predicateForIncompleteReminders(
                    withDueDateStarting: nil,
                    ending: nil,
                    calendars: calendars
                )
            }
        } else {
            predicate = await eventStore.predicateForReminders(in: calendars)
        }

        // Fetch reminders
        let ekReminders = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[EKReminder], Error>) in
            Task {
                let store = await self.eventStore
                store.fetchReminders(matching: predicate) { reminders in
                    if let reminders = reminders {
                        continuation.resume(returning: reminders)
                    } else {
                        continuation.resume(returning: [])
                    }
                }
            }
        }

        // Convert to domain models and apply additional filters
        var reminders = ekReminders.map { Reminder.from($0) }

        // Filter by tag if specified
        if let tagFilter = filter.tag {
            let tag = Tag(name: tagFilter)
            reminders = reminders.filter { $0.tags.contains(tag) }
        }

        // Apply completion filter if we used a general predicate
        if let isCompleted = filter.isCompleted, filter.dueBefore == nil && filter.dueAfter == nil {
            reminders = reminders.filter { $0.isCompleted == isCompleted }
        }

        // Sort by due date (nil dates at the end)
        reminders.sort { r1, r2 in
            switch (r1.dueDate, r2.dueDate) {
            case (nil, nil): return r1.title < r2.title
            case (nil, _): return false
            case (_, nil): return true
            case (let d1?, let d2?): return d1 < d2
            }
        }

        // Apply limit
        if let limit = filter.limit, limit > 0 {
            reminders = Array(reminders.prefix(limit))
        }

        return reminders
    }

    // MARK: - Get Reminder

    /// Gets a single reminder by ID.
    ///
    /// - Parameter id: The reminder identifier.
    /// - Returns: The reminder if found.
    public func getReminder(id: String) async throws -> Reminder {
        try await ensureAccess()

        guard let ekReminder = await eventStore.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.reminderNotFound(id)
        }

        return Reminder.from(ekReminder)
    }

    // MARK: - Create Reminder

    /// Creates a new reminder.
    ///
    /// - Parameters:
    ///   - title: The reminder title.
    ///   - notes: Optional notes.
    ///   - dueDate: Optional due date.
    ///   - listName: Optional list name (uses default if not specified).
    ///   - priority: Priority level (0=none, 1=high, 5=medium, 9=low).
    ///   - tags: Optional tags to add to notes.
    /// - Returns: The created reminder.
    public func createReminder(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        listName: String? = nil,
        priority: Int = 0,
        tags: [String] = []
    ) async throws -> Reminder {
        try await ensureAccess()

        let store = await eventStore

        // Get the target calendar
        let calendar: EKCalendar
        if let listName = listName {
            guard let list = try await getList(named: listName) else {
                throw ReminderError.listNotFound(listName)
            }
            calendar = list
        } else {
            guard let defaultCalendar = await store.defaultCalendarForNewReminders() else {
                throw ReminderError.invalidData("No default reminder list available")
            }
            calendar = defaultCalendar
        }

        // Create the reminder
        let ekReminder = EKReminder(eventStore: store)
        ekReminder.title = title
        ekReminder.calendar = calendar
        ekReminder.priority = priority

        // Set notes with tags
        var finalNotes = notes ?? ""
        if !tags.isEmpty {
            let tagObjects = tags.compactMap { Tag.from($0) }
            finalNotes = TagParser.addTags(tagObjects, to: finalNotes)
        }
        if !finalNotes.isEmpty {
            ekReminder.notes = finalNotes
        }

        // Set due date
        if let dueDate = dueDate {
            let dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: dueDate
            )
            ekReminder.dueDateComponents = dueDateComponents
        }

        // Save
        do {
            try store.save(ekReminder, commit: true)
            await Logger.shared.info("Created reminder: \(title)")
        } catch {
            await Logger.shared.error("Failed to save reminder: \(error)")
            throw ReminderError.failedToSave(error.localizedDescription)
        }

        return Reminder.from(ekReminder)
    }

    // MARK: - Update Reminder

    /// Updates an existing reminder.
    ///
    /// - Parameters:
    ///   - id: The reminder identifier.
    ///   - title: New title (optional).
    ///   - notes: New notes (optional).
    ///   - dueDate: New due date (optional, pass empty string to clear).
    ///   - priority: New priority (optional).
    ///   - addTags: Tags to add.
    ///   - removeTags: Tags to remove.
    /// - Returns: The updated reminder.
    public func updateReminder(
        id: String,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date?? = nil,
        priority: Int? = nil,
        addTags: [String] = [],
        removeTags: [String] = []
    ) async throws -> Reminder {
        try await ensureAccess()

        let store = await eventStore

        guard let ekReminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.reminderNotFound(id)
        }

        // Update fields
        if let title = title {
            ekReminder.title = title
        }

        if let notes = notes {
            ekReminder.notes = notes
        }

        // Handle tag modifications
        if !addTags.isEmpty || !removeTags.isEmpty {
            var currentNotes = ekReminder.notes ?? ""

            // Remove tags
            for tagName in removeTags {
                let tagPattern = "#\(tagName)\\b"
                if let regex = try? NSRegularExpression(pattern: tagPattern, options: .caseInsensitive) {
                    let range = NSRange(currentNotes.startIndex..., in: currentNotes)
                    currentNotes = regex.stringByReplacingMatches(
                        in: currentNotes,
                        options: [],
                        range: range,
                        withTemplate: ""
                    )
                }
            }

            // Add tags
            let newTags = addTags.compactMap { Tag.from($0) }
            currentNotes = TagParser.addTags(newTags, to: currentNotes)

            ekReminder.notes = currentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Handle due date (optional with nil meaning "clear")
        if let dueDateOption = dueDate {
            if let date = dueDateOption {
                let dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: date
                )
                ekReminder.dueDateComponents = dueDateComponents
            } else {
                // Clear the due date
                ekReminder.dueDateComponents = nil
            }
        }

        if let priority = priority {
            ekReminder.priority = priority
        }

        // Save
        do {
            try store.save(ekReminder, commit: true)
            await Logger.shared.info("Updated reminder: \(ekReminder.title ?? id)")
        } catch {
            await Logger.shared.error("Failed to update reminder: \(error)")
            throw ReminderError.failedToSave(error.localizedDescription)
        }

        return Reminder.from(ekReminder)
    }

    // MARK: - Complete Reminder

    /// Marks a reminder as complete.
    ///
    /// - Parameter id: The reminder identifier.
    /// - Returns: The updated reminder.
    public func completeReminder(id: String) async throws -> Reminder {
        try await ensureAccess()

        let store = await eventStore

        guard let ekReminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.reminderNotFound(id)
        }

        ekReminder.isCompleted = true
        ekReminder.completionDate = Date()

        do {
            try store.save(ekReminder, commit: true)
            await Logger.shared.info("Completed reminder: \(ekReminder.title ?? id)")
        } catch {
            await Logger.shared.error("Failed to complete reminder: \(error)")
            throw ReminderError.failedToSave(error.localizedDescription)
        }

        return Reminder.from(ekReminder)
    }

    // MARK: - Delete Reminder

    /// Deletes a reminder.
    ///
    /// - Parameter id: The reminder identifier.
    public func deleteReminder(id: String) async throws {
        try await ensureAccess()

        let store = await eventStore

        guard let ekReminder = store.calendarItem(withIdentifier: id) as? EKReminder else {
            throw ReminderError.reminderNotFound(id)
        }

        do {
            try store.remove(ekReminder, commit: true)
            await Logger.shared.info("Deleted reminder: \(ekReminder.title ?? id)")
        } catch {
            await Logger.shared.error("Failed to delete reminder: \(error)")
            throw ReminderError.failedToDelete(error.localizedDescription)
        }
    }
}

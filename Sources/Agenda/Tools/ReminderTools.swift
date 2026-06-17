import Foundation

/// MCP tool for listing reminders.
public struct ListRemindersTool: MCPTool {
    public let name = "list_reminders"

    public let description = """
        List reminders with optional filtering. Can filter by list name, completion status, \
        tags (extracted from notes), and due date range. Returns reminders sorted by due date.
        """

    public let inputSchema = InputSchema(
        properties: [
            "list": .string(description: "Filter by reminder list name"),
            "completed": .boolean(description: "Filter by completion status (true/false)"),
            "tag": .string(description: "Filter by tag (without # prefix)"),
            "due_before": .string(
                description: "Filter by due date before this date (ISO 8601 or natural language like 'tomorrow')",
                format: "date-time"
            ),
            "due_after": .string(
                description: "Filter by due date after this date (ISO 8601 or natural language)",
                format: "date-time"
            ),
            "limit": .integer(description: "Maximum number of reminders to return")
        ],
        required: []
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let filter = try buildFilter(from: params)
        let reminders = try await manager.listReminders(filter: filter)

        let result: [String: JSONValue] = [
            "count": .int(reminders.count),
            "reminders": .array(reminders.map { $0.toJSONValue() })
        ]

        return .json(.object(result))
    }

    private func buildFilter(from params: [String: JSONValue]) throws -> ReminderFilter {
        var filter = ReminderFilter()

        filter.listName = try params.optionalString("list")
        filter.isCompleted = try params.optionalBool("completed", default: false)
        filter.tag = try params.optionalString("tag")
        filter.limit = try params.optionalInt("limit")

        if let dueBefore = try params.optionalString("due_before") {
            filter.dueBefore = DateHelpers.parse(dueBefore)
        }

        if let dueAfter = try params.optionalString("due_after") {
            filter.dueAfter = DateHelpers.parse(dueAfter)
        }

        return filter
    }
}

/// MCP tool for creating a reminder.
public struct CreateReminderTool: MCPTool {
    public let name = "create_reminder"

    public let description = """
        Create a new reminder with title, optional notes, due date, and list. \
        Supports natural language dates like 'tomorrow' or 'next monday'. \

        You (the assistant) classify the reminder so Agenda can organize it — infer \
        gtd_status, effort, and contexts from the task itself. The user never needs to \
        provide these, and you should not mention tags or hashtags to them.
        """

    public let inputSchema = InputSchema(
        properties: [
            "title": .string(description: "The reminder title (should be actionable, starting with a verb)"),
            "notes": .string(description: "Additional notes for the reminder (plain text; do not add hashtags)"),
            "due_date": .string(
                description: "Due date (ISO 8601 or natural language like 'tomorrow', 'next friday')",
                format: "date-time"
            ),
            "list": .string(description: "The reminder list name (uses default list if not specified)"),
            "priority": .enum(
                ["none", "low", "medium", "high"],
                description: "Priority level (default: none)"
            ),
            "gtd_status": .enum(
                ["inbox", "next-action", "waiting-on", "someday-maybe", "project", "reference"],
                description: "GTD status inferred from the task. Most concrete to-dos are 'next-action'; "
                    + "use 'waiting-on' when blocked on someone, 'someday-maybe' for vague/future ideas, "
                    + "'project' for multi-step outcomes. Leave unset to let Agenda infer it."
            ),
            "effort": .enum(
                ["deep-work", "quick-task", "maintenance"],
                description: "3-3-3 effort inferred from the task: 'deep-work' for focused/creative work, "
                    + "'quick-task' for things under ~15 min, 'maintenance' for routine upkeep. Optional."
            ),
            "contexts": .array(
                of: .string(description: "A short context like 'errands', 'calls', 'home', 'computer', 'finance', 'health'"),
                description: "Where/how the task gets done, inferred from the task. Optional; Agenda infers when omitted."
            )
        ],
        required: ["title"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let title = try params.requireString("title")
        let notes = try params.optionalString("notes")
        let listName = try params.optionalString("list")

        let gtdStatus = TagInference.GTDStatus.parse(try params.optionalString("gtd_status"))
        let effort = TagInference.Effort.parse(try params.optionalString("effort"))
        let contexts = try params.optionalStringArray("contexts") ?? []

        var dueDate: Date?
        if let dueDateString = try params.optionalString("due_date") {
            dueDate = DateHelpers.parse(dueDateString)
            if dueDate == nil {
                return .error("Could not parse due date: '\(dueDateString)'. Try ISO 8601 format or natural language like 'tomorrow'.")
            }
        }

        let priority = try parsePriority(from: params)

        // The assistant classifies; Agenda fills any gaps with keyword heuristics.
        let tags = TagInference.inferReminderTags(
            title: title,
            notes: notes,
            gtdStatus: gtdStatus,
            effort: effort,
            contexts: contexts
        ).map { $0.name }

        let reminder = try await manager.createReminder(
            title: title,
            notes: notes,
            dueDate: dueDate,
            listName: listName,
            priority: priority,
            tags: tags
        )

        // Include validation warnings
        let warnings = reminder.validateTitle()
        var result = reminder.toDictionary()

        if !warnings.isEmpty {
            result["warnings"] = .array(warnings.map { .string($0) })
        }

        return .json(.object(result))
    }

    private func parsePriority(from params: [String: JSONValue]) throws -> Int {
        guard let priorityString = try params.optionalString("priority") else {
            return 0
        }

        switch priorityString.lowercased() {
        case "high": return 1
        case "medium": return 5
        case "low": return 9
        default: return 0
        }
    }
}

/// MCP tool for getting a single reminder.
public struct GetReminderTool: MCPTool {
    public let name = "get_reminder"

    public let description = "Get full details of a specific reminder by its ID."

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The reminder ID")
        ],
        required: ["id"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let reminder = try await manager.getReminder(id: id)
        return .json(reminder.toJSONValue())
    }
}

/// MCP tool for updating a reminder.
public struct UpdateReminderTool: MCPTool {
    public let name = "update_reminder"

    public let description = """
        Update an existing reminder. All fields are optional - only provide fields you want to change. \
        To clear the due date, set due_date to null. To re-classify the reminder, set gtd_status, \
        effort, or contexts (these replace the existing classification in that category; other \
        categories are preserved). Do not mention tags or hashtags to the user.
        """

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The reminder ID to update"),
            "title": .string(description: "New title for the reminder"),
            "notes": .string(description: "New notes (plain text; classification is preserved automatically)"),
            "due_date": .string(
                description: "New due date (ISO 8601 or natural language), or null to clear",
                format: "date-time"
            ),
            "priority": .enum(
                ["none", "low", "medium", "high"],
                description: "New priority level"
            ),
            "list": .string(description: "Move the reminder to this list (by name)"),
            "gtd_status": .enum(
                ["inbox", "next-action", "waiting-on", "someday-maybe", "project", "reference"],
                description: "New GTD status (replaces the current one)"
            ),
            "effort": .enum(
                ["deep-work", "quick-task", "maintenance"],
                description: "New 3-3-3 effort category (replaces the current one)"
            ),
            "contexts": .array(
                of: .string(description: "A short context like 'errands', 'calls', 'home'"),
                description: "New set of contexts (replaces all existing contexts)"
            )
        ],
        required: ["id"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let title = try params.optionalString("title")
        let providedNotes = try params.optionalString("notes")
        let listName = try params.optionalString("list")

        let gtdStatus = TagInference.GTDStatus.parse(try params.optionalString("gtd_status"))
        let effort = TagInference.Effort.parse(try params.optionalString("effort"))
        // nil = leave contexts untouched; [] = clear contexts.
        let contexts = try params.optionalStringArray("contexts")

        // Handle due date (can be string or null to clear)
        var dueDate: Date??
        if let dueDateValue = params["due_date"] {
            if case .null = dueDateValue {
                dueDate = .some(nil) // Explicitly clear
            } else if let dueDateString = dueDateValue.stringValue {
                if let parsed = DateHelpers.parse(dueDateString) {
                    dueDate = .some(parsed)
                } else {
                    return .error("Could not parse due date: '\(dueDateString)'")
                }
            }
        }

        var priority: Int?
        if let priorityString = try params.optionalString("priority") {
            switch priorityString.lowercased() {
            case "high": priority = 1
            case "medium": priority = 5
            case "low": priority = 9
            default: priority = 0
            }
        }

        // Re-derive notes (carrying the hidden classification tags) only when the
        // notes text or a classification actually changed, so editing unrelated
        // fields leaves the stored notes and tags exactly as they were.
        let reclassifies = gtdStatus != nil || effort != nil || contexts != nil
        var notes: String?
        if providedNotes != nil || reclassifies {
            let current = try await manager.getReminder(id: id)
            let humanNotes = providedNotes ?? TagParser.removeTags(from: current.notes ?? "")
            let desiredTags = TagInference.reconcileReminderTags(
                current: current.tags,
                gtdStatus: gtdStatus,
                effort: effort,
                contexts: contexts
            )
            notes = TagParser.addTags(desiredTags, to: humanNotes)
        }

        let reminder = try await manager.updateReminder(
            id: id,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            listName: listName
        )

        return .json(reminder.toJSONValue())
    }
}

/// MCP tool for completing a reminder.
public struct CompleteReminderTool: MCPTool {
    public let name = "complete_reminder"

    public let description = "Mark a reminder as completed."

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The reminder ID to complete")
        ],
        required: ["id"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let reminder = try await manager.completeReminder(id: id)
        return .json(reminder.toJSONValue())
    }
}

/// MCP tool for deleting a reminder.
public struct DeleteReminderTool: MCPTool {
    public let name = "delete_reminder"

    public let description = "Delete a reminder. This action cannot be undone."

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The reminder ID to delete")
        ],
        required: ["id"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        try await manager.deleteReminder(id: id)
        return .text("Reminder deleted successfully.")
    }
}

/// MCP tool for listing reminder lists.
public struct ListReminderListsTool: MCPTool {
    public let name = "list_reminder_lists"

    public let description = "Get all available reminder lists."

    public let inputSchema = InputSchema.empty

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let lists = try await manager.getLists()

        let result: [String: JSONValue] = [
            "count": .int(lists.count),
            "lists": .array(lists.map { list in
                .object([
                    "id": .string(list.id),
                    "name": .string(list.name)
                ])
            })
        ]

        return .json(.object(result))
    }
}

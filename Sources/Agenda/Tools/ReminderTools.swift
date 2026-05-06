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
        Tags can be included as #hashtags in notes or via the tags parameter.
        """

    public let inputSchema = InputSchema(
        properties: [
            "title": .string(description: "The reminder title (should be actionable, starting with a verb)"),
            "notes": .string(description: "Additional notes for the reminder (can include #tags)"),
            "due_date": .string(
                description: "Due date (ISO 8601 or natural language like 'tomorrow', 'next friday')",
                format: "date-time"
            ),
            "list": .string(description: "The reminder list name (uses default list if not specified)"),
            "priority": .enum(
                ["none", "low", "medium", "high"],
                description: "Priority level (default: none)"
            ),
            "tags": .array(
                of: .string(description: "Tag name without # prefix"),
                description: "Tags to add to the reminder"
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
        let tags = try params.optionalStringArray("tags") ?? []

        var dueDate: Date?
        if let dueDateString = try params.optionalString("due_date") {
            dueDate = DateHelpers.parse(dueDateString)
            if dueDate == nil {
                return .error("Could not parse due date: '\(dueDateString)'. Try ISO 8601 format or natural language like 'tomorrow'.")
            }
        }

        let priority = try parsePriority(from: params)

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
        To clear the due date, set due_date to null.
        """

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The reminder ID to update"),
            "title": .string(description: "New title for the reminder"),
            "notes": .string(description: "New notes (replaces existing notes including tags)"),
            "due_date": .string(
                description: "New due date (ISO 8601 or natural language), or null to clear",
                format: "date-time"
            ),
            "priority": .enum(
                ["none", "low", "medium", "high"],
                description: "New priority level"
            ),
            "add_tags": .array(
                of: .string(description: "Tag name without # prefix"),
                description: "Tags to add to existing notes"
            ),
            "remove_tags": .array(
                of: .string(description: "Tag name without # prefix"),
                description: "Tags to remove from notes"
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
        let notes = try params.optionalString("notes")
        let addTags = try params.optionalStringArray("add_tags") ?? []
        let removeTags = try params.optionalStringArray("remove_tags") ?? []

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

        let reminder = try await manager.updateReminder(
            id: id,
            title: title,
            notes: notes,
            dueDate: dueDate,
            priority: priority,
            addTags: addTags,
            removeTags: removeTags
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

import Foundation

/// MCP tool for creating a new reminder list.
public struct CreateReminderListTool: MCPTool {
    public let name = "create_reminder_list"

    public let description = """
        Create a new reminder list (e.g. "Work", "Errands", "Someday"). \
        Lists are how Apple Reminders groups tasks. Fails if a list with the same name already exists.
        """

    public let inputSchema = InputSchema(
        properties: [
            "name": .string(description: "The name for the new reminder list")
        ],
        required: ["name"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let name = try params.requireString("name")
        let list = try await manager.createList(named: name)

        return .json(.object([
            "id": .string(list.id),
            "name": .string(list.name),
            "message": .string("Created reminder list '\(list.name)'.")
        ]))
    }
}

/// MCP tool for renaming a reminder list.
public struct RenameReminderListTool: MCPTool {
    public let name = "rename_reminder_list"

    public let description = "Rename an existing reminder list."

    public let inputSchema = InputSchema(
        properties: [
            "name": .string(description: "The current name of the list"),
            "new_name": .string(description: "The new name for the list")
        ],
        required: ["name", "new_name"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let name = try params.requireString("name")
        let newName = try params.requireString("new_name")
        let list = try await manager.renameList(from: name, to: newName)

        return .json(.object([
            "id": .string(list.id),
            "name": .string(list.name),
            "message": .string("Renamed list to '\(list.name)'.")
        ]))
    }
}

/// MCP tool for deleting a reminder list.
public struct DeleteReminderListTool: MCPTool {
    public let name = "delete_reminder_list"

    public let description = """
        Delete a reminder list and ALL reminders inside it. This action cannot be undone. \
        Read-only/system lists cannot be deleted.
        """

    public let inputSchema = InputSchema(
        properties: [
            "name": .string(description: "The name of the list to delete")
        ],
        required: ["name"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let name = try params.requireString("name")
        try await manager.deleteList(named: name)
        return .text("Deleted reminder list '\(name)' and its reminders.")
    }
}

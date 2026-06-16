import Foundation

/// MCP tool for completing multiple reminders at once.
public struct CompleteRemindersTool: MCPTool {
    public let name = "complete_reminders"

    public let description = """
        Mark multiple reminders as complete in one call. Useful for clearing a batch of \
        finished tasks. Reminders that cannot be found are reported individually without \
        failing the whole operation.
        """

    public let inputSchema = InputSchema(
        properties: [
            "ids": .array(
                of: .string(description: "A reminder ID"),
                description: "The reminder IDs to complete"
            )
        ],
        required: ["ids"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        guard let ids = try params.optionalStringArray("ids"), !ids.isEmpty else {
            return .error("Provide a non-empty 'ids' array of reminder IDs to complete.")
        }
        let result = try await manager.completeReminders(ids: ids)
        return .json(result.toJSONValue())
    }
}

/// MCP tool for deleting multiple reminders at once.
public struct DeleteRemindersTool: MCPTool {
    public let name = "delete_reminders"

    public let description = """
        Delete multiple reminders in one call. This action cannot be undone. Reminders that \
        cannot be found are reported individually without failing the whole operation.
        """

    public let inputSchema = InputSchema(
        properties: [
            "ids": .array(
                of: .string(description: "A reminder ID"),
                description: "The reminder IDs to delete"
            )
        ],
        required: ["ids"]
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        guard let ids = try params.optionalStringArray("ids"), !ids.isEmpty else {
            return .error("Provide a non-empty 'ids' array of reminder IDs to delete.")
        }
        let result = try await manager.deleteReminders(ids: ids)
        return .json(result.toJSONValue())
    }
}

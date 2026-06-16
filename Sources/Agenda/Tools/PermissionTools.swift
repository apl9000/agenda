import Foundation

/// MCP tool for checking (and triggering) EventKit permission grants.
///
/// On first run macOS only shows the Reminders/Calendar permission prompt when
/// access is actually requested. Calling this tool is a friendly way to trigger
/// those prompts up front and to diagnose "nothing is working" setup issues.
public struct CheckPermissionsTool: MCPTool {
    public let name = "check_permissions"

    public let description = """
        Check whether Agenda has access to Reminders and Calendar, requesting access if it \
        has not been determined yet. Use this first if other tools report permission errors.
        """

    public let inputSchema = InputSchema.empty

    private let permissions: PermissionsHandler

    public init(permissions: PermissionsHandler) {
        self.permissions = permissions
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        // Attempt to obtain access so macOS surfaces the prompt on first run.
        // We intentionally swallow the throw here and report status instead, so
        // a denied permission produces a helpful report rather than an error.
        try? await permissions.requestAllAccess()

        let status = await permissions.getStatus()
        var result = status.toJSONValue().objectValue ?? [:]

        if !status.allGranted {
            result["help"] = .string(
                "Grant access in System Settings > Privacy & Security > Reminders and Calendars, "
                + "then try again."
            )
        }

        return .json(.object(result))
    }
}

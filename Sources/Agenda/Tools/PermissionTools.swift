import Foundation

/// MCP tool for checking (and, when still undetermined, requesting) EventKit access.
///
/// The result is the raw `EKAuthorizationStatus` for each entity, whether a
/// full-access request was attempted, and that request's boolean result or
/// error domain and code. Those are separate fields. A failed request is not
/// reported as `denied`. This tool does not list calendars, events, or reminders.
public struct CheckPermissionsTool: MCPTool {
    public let name = "check_permissions"

    public let description = """
        Report EventKit authorization for Reminders and Calendar. When a status is \
        notDetermined, this requests full access once and reports whether that call \
        returned true or false, or the error domain and code. Status stays the raw \
        EventKit value (notDetermined, restricted, denied, fullAccess, writeOnly, \
        authorized). Does not list calendars, events, or reminders.
        """

    public let inputSchema = InputSchema.empty

    private let permissions: PermissionsHandler

    public init(permissions: PermissionsHandler) {
        self.permissions = permissions
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let diagnostic = await permissions.diagnoseAccess()
        return .json(try diagnostic.toJSONValue())
    }
}

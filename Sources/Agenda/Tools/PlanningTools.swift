import Foundation

/// MCP tool that recommends the single best next action (and a few alternatives).
///
/// This is Agenda's antidote to decision paralysis: instead of returning a flat
/// list, it ranks open reminders by urgency, explicit `#next-action` intent, and
/// priority, then hands back the one thing to do now.
public struct WhatsNextTool: MCPTool {
    public let name = "whats_next"

    public let description = """
        Recommend what to work on next. Ranks incomplete reminders by overdue/due-today \
        status, #next-action tag, and priority, deferring #waiting-on and #someday-maybe items. \
        Returns a single recommended task plus a short ranked list of alternatives.
        """

    public let inputSchema = InputSchema(
        properties: [
            "list": .string(description: "Only consider reminders in this list (by name)"),
            "limit": .integer(description: "How many alternatives to return (default 5)")
        ],
        required: []
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        var filter = ReminderFilter()
        filter.isCompleted = false
        filter.listName = try params.optionalString("list")

        let limit = try params.optionalInt("limit") ?? 5
        let reminders = try await manager.listReminders(filter: filter)
        let ranked = Planner.rankNextActions(reminders)

        var result: [String: JSONValue] = [
            "count": .int(ranked.count)
        ]

        if let recommended = ranked.first {
            result["recommended"] = recommended.toJSONValue()
            let alternatives = ranked.dropFirst().prefix(max(0, limit))
            result["alternatives"] = .array(alternatives.map { $0.toJSONValue() })
        } else {
            result["message"] = .string("Nothing open right now. Inbox zero. 🎉")
            result["alternatives"] = .array([])
        }

        return .json(.object(result))
    }
}

/// MCP tool that builds a structured day plan using the 3-3-3 framework.
public struct PlanMyDayTool: MCPTool {
    public let name = "plan_my_day"

    public let description = """
        Build a focused plan for today using the 3-3-3 framework: up to 3 deep-work items \
        (#deep-work), 3 quick tasks (#quick-task), and 3 maintenance items (#maintenance), \
        plus what's overdue, what's due today, and the single best thing to start with.
        """

    public let inputSchema = InputSchema(
        properties: [
            "list": .string(description: "Only plan from reminders in this list (by name)")
        ],
        required: []
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        var filter = ReminderFilter()
        filter.isCompleted = false
        filter.listName = try params.optionalString("list")

        let reminders = try await manager.listReminders(filter: filter)
        let plan = Planner.planDay(reminders)
        return .json(plan.toJSONValue())
    }
}

/// MCP tool that produces a GTD-style weekly review of open loops.
public struct WeeklyReviewTool: MCPTool {
    public let name = "weekly_review"

    public let description = """
        Run a GTD-style review of open reminders. Surfaces unclarified tasks (no GTD tag), \
        stale #inbox items, #waiting-on items to follow up, overdue tasks, and #someday-maybe \
        items to reconsider — so nothing falls through the cracks.
        """

    public let inputSchema = InputSchema(
        properties: [
            "list": .string(description: "Only review reminders in this list (by name)"),
            "stale_after_days": .integer(
                description: "How many days before an #inbox item counts as stale (default 7)"
            )
        ],
        required: []
    )

    private let manager: RemindersManager

    public init(manager: RemindersManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        var filter = ReminderFilter()
        filter.isCompleted = false
        filter.listName = try params.optionalString("list")

        let staleAfterDays = try params.optionalInt("stale_after_days") ?? 7
        let reminders = try await manager.listReminders(filter: filter)
        let report = Planner.review(reminders, staleAfterDays: staleAfterDays)
        return .json(report.toJSONValue())
    }
}

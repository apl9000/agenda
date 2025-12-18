import Foundation

/// MCP tool for listing calendar events.
public struct ListEventsTool: MCPTool {
    public let name = "list_events"

    public let description = """
        List calendar events within a date range. Defaults to showing events for the next 7 days. \
        Can filter by calendar name and limit results.
        """

    public let inputSchema = InputSchema(
        properties: [
            "calendar": .string(description: "Filter by calendar name"),
            "start_date": .string(
                description: "Start of date range (ISO 8601 or natural language like 'today'). Defaults to now.",
                format: "date-time"
            ),
            "end_date": .string(
                description: "End of date range (ISO 8601 or natural language like 'next week'). Defaults to 7 days from now.",
                format: "date-time"
            ),
            "limit": .integer(description: "Maximum number of events to return")
        ],
        required: []
    )

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let filter = try buildFilter(from: params)
        let events = try await manager.listEvents(filter: filter)

        let result: [String: JSONValue] = [
            "count": .int(events.count),
            "dateRange": .object([
                "start": .string(DateHelpers.formatISO8601(filter.startDate)),
                "end": .string(DateHelpers.formatISO8601(filter.endDate))
            ]),
            "events": .array(events.map { $0.toJSONValue() })
        ]

        return .json(.object(result))
    }

    private func buildFilter(from params: [String: JSONValue]) throws -> EventFilter {
        var filter = EventFilter()

        filter.calendarName = try params.optionalString("calendar")
        filter.limit = try params.optionalInt("limit")

        if let startString = try params.optionalString("start_date") {
            if let date = DateHelpers.parse(startString) {
                filter.startDate = date
            }
        }

        if let endString = try params.optionalString("end_date") {
            if let date = DateHelpers.parse(endString) {
                filter.endDate = date
            }
        }

        return filter
    }
}

/// MCP tool for creating a calendar event.
public struct CreateEventTool: MCPTool {
    public let name = "create_event"

    public let description = """
        Create a new calendar event. Requires title, start date, and end date. \
        Supports natural language dates like 'tomorrow at 2pm'.
        """

    public let inputSchema = InputSchema(
        properties: [
            "title": .string(description: "The event title"),
            "start_date": .string(
                description: "Event start date/time (ISO 8601 or natural language)",
                format: "date-time"
            ),
            "end_date": .string(
                description: "Event end date/time (ISO 8601 or natural language)",
                format: "date-time"
            ),
            "all_day": .boolean(
                description: "Whether this is an all-day event",
                default: false
            ),
            "notes": .string(description: "Additional notes for the event"),
            "location": .string(description: "Event location"),
            "calendar": .string(description: "Calendar name (uses default calendar if not specified)"),
            "url": .string(description: "URL associated with the event"),
            "availability": .enum(
                ["busy", "free", "tentative", "unavailable"],
                description: "Availability during the event (default: busy)"
            )
        ],
        required: ["title", "start_date", "end_date"]
    )

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let title = try params.requireString("title")
        let startString = try params.requireString("start_date")
        let endString = try params.requireString("end_date")

        guard let startDate = DateHelpers.parse(startString) else {
            return .error("Could not parse start date: '\(startString)'")
        }

        guard let endDate = DateHelpers.parse(endString) else {
            return .error("Could not parse end date: '\(endString)'")
        }

        let isAllDay = try params.optionalBool("all_day", default: false)
        let notes = try params.optionalString("notes")
        let location = try params.optionalString("location")
        let calendarName = try params.optionalString("calendar")
        let url = try params.optionalString("url")
        let availability = try parseAvailability(from: params)

        let event = try await manager.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            notes: notes,
            location: location,
            calendarName: calendarName,
            url: url,
            availability: availability
        )

        return .json(event.toJSONValue())
    }

    private func parseAvailability(from params: [String: JSONValue]) throws -> Event.Availability {
        guard let availString = try params.optionalString("availability") else {
            return .busy
        }

        switch availString.lowercased() {
        case "busy": return .busy
        case "free": return .free
        case "tentative": return .tentative
        case "unavailable": return .unavailable
        default: return .busy
        }
    }
}

/// MCP tool for getting a single event.
public struct GetEventTool: MCPTool {
    public let name = "get_event"

    public let description = "Get full details of a specific calendar event by its ID."

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The event ID")
        ],
        required: ["id"]
    )

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let event = try await manager.getEvent(id: id)
        return .json(event.toJSONValue())
    }
}

/// MCP tool for updating an event.
public struct UpdateEventTool: MCPTool {
    public let name = "update_event"

    public let description = """
        Update an existing calendar event. All fields are optional - only provide fields you want to change.
        """

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The event ID to update"),
            "title": .string(description: "New title for the event"),
            "start_date": .string(
                description: "New start date/time (ISO 8601 or natural language)",
                format: "date-time"
            ),
            "end_date": .string(
                description: "New end date/time (ISO 8601 or natural language)",
                format: "date-time"
            ),
            "all_day": .boolean(description: "Whether this is an all-day event"),
            "notes": .string(description: "New notes for the event"),
            "location": .string(description: "New location"),
            "url": .string(description: "New URL"),
            "availability": .enum(
                ["busy", "free", "tentative", "unavailable"],
                description: "New availability status"
            )
        ],
        required: ["id"]
    )

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let title = try params.optionalString("title")
        let notes = try params.optionalString("notes")
        let location = try params.optionalString("location")
        let url = try params.optionalString("url")

        var startDate: Date?
        if let startString = try params.optionalString("start_date") {
            startDate = DateHelpers.parse(startString)
            if startDate == nil {
                return .error("Could not parse start date: '\(startString)'")
            }
        }

        var endDate: Date?
        if let endString = try params.optionalString("end_date") {
            endDate = DateHelpers.parse(endString)
            if endDate == nil {
                return .error("Could not parse end date: '\(endString)'")
            }
        }

        var isAllDay: Bool?
        if let allDayValue = params["all_day"], let boolValue = allDayValue.boolValue {
            isAllDay = boolValue
        }

        var availability: Event.Availability?
        if let availString = try params.optionalString("availability") {
            switch availString.lowercased() {
            case "busy": availability = .busy
            case "free": availability = .free
            case "tentative": availability = .tentative
            case "unavailable": availability = .unavailable
            default: break
            }
        }

        let event = try await manager.updateEvent(
            id: id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            notes: notes,
            location: location,
            url: url,
            availability: availability
        )

        return .json(event.toJSONValue())
    }
}

/// MCP tool for deleting an event.
public struct DeleteEventTool: MCPTool {
    public let name = "delete_event"

    public let description = """
        Delete a calendar event. For recurring events, can optionally delete all future occurrences.
        """

    public let inputSchema = InputSchema(
        properties: [
            "id": .string(description: "The event ID to delete"),
            "delete_all_occurrences": .boolean(
                description: "For recurring events, delete all future occurrences (default: false)",
                default: false
            )
        ],
        required: ["id"]
    )

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let id = try params.requireString("id")
        let deleteAll = try params.optionalBool("delete_all_occurrences", default: false)

        try await manager.deleteEvent(id: id, deleteAllOccurrences: deleteAll)
        return .text("Event deleted successfully.")
    }
}

/// MCP tool for listing calendars.
public struct ListCalendarsTool: MCPTool {
    public let name = "list_calendars"

    public let description = "Get all available calendars."

    public let inputSchema = InputSchema.empty

    private let manager: CalendarManager

    public init(manager: CalendarManager) {
        self.manager = manager
    }

    public func execute(params: [String: JSONValue]) async throws -> ToolResult {
        let calendars = try await manager.getCalendars()

        let result: [String: JSONValue] = [
            "count": .int(calendars.count),
            "calendars": .array(calendars.map { cal in
                .object([
                    "id": .string(cal.id),
                    "name": .string(cal.name),
                    "color": .string(cal.color)
                ])
            })
        ]

        return .json(.object(result))
    }
}

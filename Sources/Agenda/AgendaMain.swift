import Foundation

/// Agenda MCP Server
///
/// An opinionated MCP server for interacting with Apple Reminders and Calendar.
/// Designed for GTD workflows and neurodivergent users.
@main
struct Agenda {
    /// Application version
    static let version = "0.2.0"

    static func main() async {
        // Parse command line arguments
        let arguments = CommandLine.arguments

        if arguments.contains("--help") || arguments.contains("-h") {
            printHelp()
            return
        }

        if arguments.contains("--version") || arguments.contains("-v") {
            print("Agenda MCP Server v\(version)")
            return
        }

        // Configure logging
        if arguments.contains("--debug") {
            await Logger.shared.setLevel(.debug)
        }

        // Run the server
        await runServer()
    }

    /// Prints help information.
    static func printHelp() {
        print("""
        Agenda - MCP Server for Apple Reminders and Calendar

        USAGE:
            agenda [OPTIONS]

        OPTIONS:
            -h, --help      Show this help message
            -v, --version   Show version information
            --debug         Enable debug logging

        DESCRIPTION:
            Agenda is a Model Context Protocol (MCP) server that provides
            access to Apple Reminders and Calendar apps. It's designed to
            work with Claude Desktop, VS Code, and other MCP clients.

            The server communicates via JSON-RPC 2.0 over stdin/stdout.
            All logs are written to stderr.

        CONFIGURATION:
            Claude Desktop:
                Add to ~/Library/Application Support/Claude/claude_desktop_config.json:
                {
                    "mcpServers": {
                        "agenda": {
                            "command": "/path/to/agenda"
                        }
                    }
                }

        AVAILABLE TOOLS:
            Reminders:
                - list_reminders        List reminders with filtering
                - create_reminder       Create a new reminder
                - get_reminder          Get reminder details
                - update_reminder       Update or move a reminder
                - complete_reminder     Mark reminder as complete
                - delete_reminder       Delete a reminder
                - complete_reminders    Complete many reminders at once
                - delete_reminders      Delete many reminders at once

            Lists:
                - list_reminder_lists   Get all reminder lists
                - create_reminder_list  Create a new list
                - rename_reminder_list  Rename a list
                - delete_reminder_list  Delete a list and its reminders

            Planning (opinionated):
                - whats_next            Recommend the single best next action
                - plan_my_day           Build a 3-3-3 plan for today
                - weekly_review         GTD-style review of open loops

            Calendar:
                - list_events           List calendar events
                - create_event          Create a new event
                - get_event             Get event details
                - update_event          Update an event
                - delete_event          Delete an event
                - list_calendars        Get all calendars

            Utility:
                - check_permissions     Check / request Reminders & Calendar access

        PERMISSIONS:
            On first run, macOS will prompt for access to Reminders and Calendar.
            Grant access in System Settings > Privacy & Security.

        For more information, visit: https://github.com/apl9000/agenda
        """)
    }

    /// Runs the MCP server.
    static func runServer() async {
        await Logger.shared.info("Agenda MCP Server v\(version) starting...")

        // Create shared permissions handler
        let permissions = PermissionsHandler()

        // Create managers
        let remindersManager = RemindersManager(permissions: permissions)
        let calendarManager = CalendarManager(permissions: permissions)

        // Create server
        let server = MCPServer(name: "Agenda", version: version)

        // Register reminder tools
        let reminderTools: [any MCPTool] = [
            ListRemindersTool(manager: remindersManager),
            CreateReminderTool(manager: remindersManager),
            GetReminderTool(manager: remindersManager),
            UpdateReminderTool(manager: remindersManager),
            CompleteReminderTool(manager: remindersManager),
            DeleteReminderTool(manager: remindersManager),
            ListReminderListsTool(manager: remindersManager)
        ]

        // Register list-management tools
        let listTools: [any MCPTool] = [
            CreateReminderListTool(manager: remindersManager),
            RenameReminderListTool(manager: remindersManager),
            DeleteReminderListTool(manager: remindersManager)
        ]

        // Register bulk-operation tools
        let bulkTools: [any MCPTool] = [
            CompleteRemindersTool(manager: remindersManager),
            DeleteRemindersTool(manager: remindersManager)
        ]

        // Register opinionated planning tools
        let planningTools: [any MCPTool] = [
            WhatsNextTool(manager: remindersManager),
            PlanMyDayTool(manager: remindersManager),
            WeeklyReviewTool(manager: remindersManager)
        ]

        // Register calendar tools
        let calendarTools: [any MCPTool] = [
            ListEventsTool(manager: calendarManager),
            CreateEventTool(manager: calendarManager),
            GetEventTool(manager: calendarManager),
            UpdateEventTool(manager: calendarManager),
            DeleteEventTool(manager: calendarManager),
            ListCalendarsTool(manager: calendarManager)
        ]

        // Register utility tools
        let utilityTools: [any MCPTool] = [
            CheckPermissionsTool(permissions: permissions)
        ]

        do {
            try await server.registerTools(reminderTools)
            try await server.registerTools(listTools)
            try await server.registerTools(bulkTools)
            try await server.registerTools(planningTools)
            try await server.registerTools(calendarTools)
            try await server.registerTools(utilityTools)
            let total = reminderTools.count + listTools.count + bulkTools.count
                + planningTools.count + calendarTools.count + utilityTools.count
            await Logger.shared.info("Registered \(total) tools")
        } catch {
            await Logger.shared.error("Failed to register tools: \(error)")
            exit(1)
        }

        // Handle termination signals
        setupSignalHandlers(server: server)

        // Run the server
        await server.run()
    }

    /// Retains the dispatch signal sources for the lifetime of the process.
    ///
    /// `signal(2)` requires a context-free C function pointer, so we cannot
    /// capture `server` in a plain handler. `DispatchSource` signal sources can
    /// capture context, but must be retained or they stop firing.
    private static var signalSources: [DispatchSourceSignal] = []

    /// Sets up signal handlers for graceful shutdown.
    static func setupSignalHandlers(server: MCPServer) {
        for sig in [SIGINT, SIGTERM] {
            // Ignore the default disposition so the dispatch source receives it.
            signal(sig, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
            source.setEventHandler {
                Task {
                    await Logger.shared.info("Received signal \(sig), shutting down...")
                    await server.stop()
                }
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

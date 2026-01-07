import Foundation

/// Agenda MCP Server
///
/// An opinionated MCP server for interacting with Apple Reminders and Calendar.
/// Designed for GTD workflows and neurodivergent users.
@main
struct Agenda {
    /// Application version
    static let version = "0.1.0"

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
                - list_reminders     List reminders with filtering
                - create_reminder    Create a new reminder
                - get_reminder       Get reminder details
                - update_reminder    Update a reminder
                - complete_reminder  Mark reminder as complete
                - delete_reminder    Delete a reminder
                - list_reminder_lists Get all reminder lists

            Calendar:
                - list_events        List calendar events
                - create_event       Create a new event
                - get_event          Get event details
                - update_event       Update an event
                - delete_event       Delete an event
                - list_calendars     Get all calendars

        PERMISSIONS:
            On first run, macOS will prompt for access to Reminders and Calendar.
            Grant access in System Settings > Privacy & Security.

        For more information, visit: https://github.com/yourusername/agenda
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

        // Register calendar tools
        let calendarTools: [any MCPTool] = [
            ListEventsTool(manager: calendarManager),
            CreateEventTool(manager: calendarManager),
            GetEventTool(manager: calendarManager),
            UpdateEventTool(manager: calendarManager),
            DeleteEventTool(manager: calendarManager),
            ListCalendarsTool(manager: calendarManager)
        ]

        do {
            try await server.registerTools(reminderTools)
            try await server.registerTools(calendarTools)
            await Logger.shared.info("Registered \(reminderTools.count + calendarTools.count) tools")
        } catch {
            await Logger.shared.error("Failed to register tools: \(error)")
            exit(1)
        }

        // Handle termination signals
        setupSignalHandlers(server: server)

        // Run the server
        await server.run()
    }

    /// Sets up signal handlers for graceful shutdown.
    static func setupSignalHandlers(server: MCPServer) {
        // Handle SIGINT (Ctrl+C)
        signal(SIGINT) { _ in
            Task {
                await Logger.shared.info("Received SIGINT, shutting down...")
                await server.stop()
            }
        }

        // Handle SIGTERM
        signal(SIGTERM) { _ in
            Task {
                await Logger.shared.info("Received SIGTERM, shutting down...")
                await server.stop()
            }
        }
    }
}

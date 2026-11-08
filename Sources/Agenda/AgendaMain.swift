import Foundation

/// How the `agenda` executable should run for one invocation.
enum AgendaCommand: Equatable {
    case help
    case version
    /// Print the permission diagnostic as JSON and exit.
    case checkPermissions(debug: Bool)
    case serve(debug: Bool)
}

/// Agenda MCP Server
///
/// An opinionated MCP server for interacting with Apple Reminders and Calendar.
/// Designed for GTD workflows and neurodivergent users.
@main
struct Agenda {
    /// Application version. Keep in sync with `CFBundleShortVersionString`
    /// in `Sources/Agenda/Info.plist`.
    static let version = "0.2.0"

    static func main() async {
        switch command(from: CommandLine.arguments) {
        case .help:
            printHelp()
        case .version:
            print("Agenda MCP Server v\(version)")
        case .checkPermissions(let debug):
            if debug {
                await Logger.shared.setLevel(.debug)
            }
            await printPermissionDiagnostic()
        case .serve(let debug):
            if debug {
                await Logger.shared.setLevel(.debug)
            }
            await runServer()
        }
    }

    /// Parses `CommandLine.arguments`, including the program name at index 0.
    static func command(from arguments: [String]) -> AgendaCommand {
        let flags = Set(arguments.dropFirst())
        if flags.contains("--help") || flags.contains("-h") {
            return .help
        }
        if flags.contains("--version") || flags.contains("-v") {
            return .version
        }
        let debug = flags.contains("--debug")
        if flags.contains("--check-permissions") {
            return .checkPermissions(debug: debug)
        }
        return .serve(debug: debug)
    }

    /// Prints help information.
    static func printHelp() {
        print("""
        Agenda - MCP Server for Apple Reminders and Calendar

        USAGE:
            agenda [OPTIONS]

        OPTIONS:
            -h, --help             Show this help message
            -v, --version          Show version information
            --debug                Enable debug logging
            --check-permissions    Print Reminders and Calendar authorization
                                   as JSON, then exit. Does not list events
                                   or reminders.

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
            Agenda requests full access to Reminders and Calendar. macOS
            attributes that prompt to the app that launched this binary.
            The controls are that app's rows in
            System Settings > Privacy & Security > Reminders and Calendars.
            Use --check-permissions to print the EventKit status and the
            request result without starting the server.

        For more information, visit: https://github.com/apl9000/agenda
        """)
    }

    /// Prints the permission diagnostic as JSON on stdout and returns.
    ///
    /// Does not start the MCP server and does not list calendar or reminder
    /// data. Failures to encode the report go to stderr without the report
    /// body. Request failures logged by the diagnostic include only an
    /// entity name, an error domain, and an error code.
    static func printPermissionDiagnostic() async {
        let diagnostic = await PermissionsHandler().diagnoseAccess()
        do {
            let data = try diagnostic.jsonData()
            try FileHandle.standardOutput.write(contentsOf: data)
            try FileHandle.standardOutput.write(contentsOf: Data("\n".utf8))
        } catch {
            let line = "agenda: failed to encode the permission diagnostic\n"
            try? FileHandle.standardError.write(contentsOf: Data(line.utf8))
            exit(1)
        }
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
        setupSignalHandlers()

        // Run the server
        await server.run()
    }

    /// Retains the dispatch signal sources for the lifetime of the process.
    ///
    /// `signal(2)` requires a context-free C function pointer, so we use
    /// `DispatchSource` signal sources instead. They must be retained or they
    /// stop firing.
    private static var signalSources: [DispatchSourceSignal] = []

    /// Sets up signal handlers so SIGINT/SIGTERM terminate the process promptly.
    static func setupSignalHandlers() {
        for sig in [SIGINT, SIGTERM] {
            // Ignore the default disposition so the dispatch source receives it.
            signal(sig, SIG_IGN)

            let source = DispatchSource.makeSignalSource(signal: sig, queue: .global())
            source.setEventHandler {
                // The run loop blocks on readLine(), so flipping `isRunning` is
                // not enough to interrupt it — terminate the process directly.
                FileHandle.standardError.write(Data("agenda: received signal \(sig), shutting down\n".utf8))
                exit(0)
            }
            source.resume()
            signalSources.append(source)
        }
    }
}

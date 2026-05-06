# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Agenda is an MCP (Model Context Protocol) server for interacting with Apple's Reminders and Calendar apps. It's designed for GTD workflows and neurodivergent users, providing tag-based organization and natural language date parsing.

## Build Commands

```bash
# Build
swift build

# Build release
swift build -c release

# Run
swift run agenda

# Run with debug logging
swift run agenda --debug

# Test
swift test

# Run a single test class
swift test --filter TagTests

# Run a single test method
swift test --filter TagTests.testExtractTags
```

## Architecture

Three-layer architecture:

1. **MCP Layer** (`Sources/Agenda/MCP/`) - JSON-RPC 2.0 protocol handling
   - `MCPServer.swift` - Main server loop, routes methods
   - `JSONRPCHandler.swift` - Request/response encoding
   - `ToolRegistry.swift` - Tool registration and dispatch
   - `Models/` - Protocol types (JSONRPCRequest, JSONRPCResponse, ToolDefinition)

2. **Tools Layer** (`Sources/Agenda/Tools/`) - MCP tool implementations
   - `ReminderTools.swift` - 7 reminder tools
   - `CalendarTools.swift` - 6 calendar tools

3. **EventKit Layer** (`Sources/Agenda/EventKit/`) - Apple API wrappers
   - `PermissionsHandler.swift` - Permission management (actor)
   - `RemindersManager.swift` - Reminder CRUD operations (actor)
   - `CalendarManager.swift` - Calendar CRUD operations (actor)
   - `Models/` - Domain models (Reminder, Event, Tag)

## Key Patterns

### Actors for Thread Safety
All managers and handlers are actors: `MCPServer`, `ToolRegistry`, `PermissionsHandler`, `RemindersManager`, `CalendarManager`, `Logger`, `JSONRPCHandler`.

### Protocol-Based Tools
Tools implement `MCPTool` protocol with `name`, `description`, `inputSchema`, and async `execute(params:)`.

### Tag System
Tags are #hashtags extracted from reminder notes. GTD contexts: `#inbox`, `#next-action`, `#waiting-on`, `#someday-maybe`, `#project`, `#reference`.

### Logging
All logs go to stderr (stdout is for JSON-RPC). Use `logDebug()`, `logInfo()`, `logWarning()`, `logError()`.

## Error Handling

- Never use force unwrap (`!`) or `try!`
- Custom error types: `PermissionError`, `ReminderError`, `CalendarError`, `ParameterError`
- Errors map to JSON-RPC codes: `-32000` (permission), `-32001` (not found), `-32002` (operation failed)

## Adding New Tools

1. Create struct implementing `MCPTool` in `Sources/Agenda/Tools/`
2. Define `name`, `description`, `inputSchema`
3. Implement `execute(params:) async throws -> ToolResult`
4. Register in `main.swift` via `server.registerTool()`

## Testing

- Unit tests in `Tests/AgendaTests/`
- Tests for JSON-RPC, Tags, DateHelpers, ToolRegistry
- EventKit integration tests require system permissions

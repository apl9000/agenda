# Architecture

This document describes the technical architecture of the Agenda MCP server.

> **Note**: As of 0.2.0 the server provides full Reminders + Calendar CRUD, list management, bulk operations, opinionated planning (`whats_next` / `plan_my_day` / `weekly_review`), and automatic tag inference. The heavier "AI Engine" and on-device learning layers described in [CONSTITUTION.md](CONSTITUTION.md) remain future work — today the *connected* assistant supplies the intelligence, guided by the server's tool schemas and `instructions`.

## Overview

Agenda is structured in three main layers:

```
┌─────────────────────────────────────────────┐
│               MCP Layer                      │
│  (JSON-RPC protocol, tool definitions)       │
├─────────────────────────────────────────────┤
│              Tools Layer                     │
│  (Tool implementations, parameter parsing)   │
├─────────────────────────────────────────────┤
│            EventKit Layer                    │
│  (Apple APIs, permissions, data models)      │
└─────────────────────────────────────────────┘
```

## Architectural Principles

The architecture follows the principles defined in [CONSTITUTION.md](CONSTITUTION.md):

1. **Swift-First, Native Experience** - Deep EventKit integration for reliability
2. **AI as Augmentation** - Architecture prepared for Phase 1 AI layer (not yet implemented)
3. **Incremental Complexity** - Each layer works independently
4. **Data Sovereignty** - Local-first design, all data stays on device

## Directory Structure

```
Sources/Agenda/
├── AgendaMain.swift            # Entry point (@main), CLI handling, tool registration
├── MCP/
│   ├── MCPServer.swift        # Main server loop, method routing
│   ├── JSONRPCHandler.swift   # JSON-RPC encoding/decoding
│   ├── ToolRegistry.swift     # Tool registration and dispatch
│   └── Models/
│       ├── JSONRPCRequest.swift   # Request types
│       ├── JSONRPCResponse.swift  # Response types
│       └── ToolDefinition.swift   # Tool schema types
├── EventKit/
│   ├── PermissionsHandler.swift   # Permission management
│   ├── RemindersManager.swift     # Reminders CRUD operations
│   ├── CalendarManager.swift      # Calendar CRUD operations
│   └── Models/
│       ├── Reminder.swift         # Reminder domain model
│       ├── Event.swift            # Event domain model
│       └── Tag.swift              # Tag parsing and GTD support
├── Tools/
│   ├── ReminderTools.swift    # Reminder CRUD MCP tools
│   ├── ListTools.swift        # Reminder list management tools
│   ├── BulkTools.swift        # Bulk complete/delete tools
│   ├── PlanningTools.swift    # whats_next / plan_my_day / weekly_review
│   ├── PermissionTools.swift  # check_permissions
│   └── CalendarTools.swift    # Calendar MCP tools
└── Utilities/
    ├── Logger.swift           # stderr logging
    ├── DateHelpers.swift      # Date parsing utilities
    ├── Planner.swift          # Pure opinionated ranking/planning/review logic
    └── TagInference.swift     # Pure tag classification + keyword fallback
```

## Core Components

### MCPServer

The main server actor that:

- Reads JSON-RPC requests from stdin
- Routes methods to appropriate handlers
- Writes JSON-RPC responses to stdout
- Manages the server lifecycle

Key methods:

- `initialize` - MCP protocol handshake
- `tools/list` - Returns available tools
- `tools/call` - Executes a tool

### ToolRegistry

An actor managing tool registration and dispatch:

- Stores registered tools by name
- Provides tool definitions for `tools/list`
- Dispatches `tools/call` to implementations

### JSONRPCHandler

Handles JSON encoding/decoding:

- Parses requests with validation
- Encodes responses
- Converts between Swift types and JSONValue

### PermissionsHandler

Manages EventKit permissions:

- Requests access to Reminders and Calendar
- Caches permission status
- Provides shared EKEventStore instance

### RemindersManager / CalendarManager

Actor-based wrappers around EventKit:

- Async/await interface
- Error mapping to domain errors
- Data conversion between EKReminder/EKEvent and domain models
- Reminder list management (create/rename/delete) and moving reminders between lists
- Bulk complete/delete with a single commit and partial-failure reporting

### Pure Domain Logic (`Utilities/`)

Two stateless engines hold the opinionated behavior, deliberately free of EventKit
so they are unit-testable on any platform:

- **`Planner`** — ranks next actions and builds the `plan_my_day` / `weekly_review`
  outputs from `[Reminder]`.
- **`TagInference`** — turns the structured `gtd_status` / `effort` / `contexts`
  (and event `categories`) parameters into tags, filling gaps with keyword
  heuristics. The connected assistant is told to classify items itself via the
  `instructions` returned from `initialize`; the user never types a tag.

## Data Flow

### Request Processing

```
stdin → MCPServer.run() → parseRequest → routeMethod
                                              │
                    ┌─────────────────────────┼─────────────────────────┐
                    │                         │                         │
              initialize              tools/list               tools/call
                    │                         │                         │
            return capabilities      return definitions        ToolRegistry.execute
                                                                       │
                                                                 MCPTool.execute
                                                                       │
                                                              RemindersManager
                                                              CalendarManager
                                                                       │
                                                                 ToolResult
                                                                       │
stdout ← encodeResponse ← JSONRPCResponse ← routeMethod ←──────────────┘
```

### Tool Execution

```
tools/call request
       │
       ▼
ToolRegistry.execute(name, params)
       │
       ▼
MCPTool.execute(params)
       │
       ├── Parse parameters (throw if invalid)
       │
       ├── Call manager method (await)
       │        │
       │        ▼
       │   Manager validates permissions
       │        │
       │        ▼
       │   Manager calls EventKit
       │        │
       │        ▼
       │   Convert EKReminder/EKEvent to domain model
       │
       ▼
Return ToolResult (text or JSON)
```

## Concurrency Model

### Actors

The following are implemented as actors for thread safety:

- `MCPServer` - Server state (running, initialized)
- `ToolRegistry` - Mutable tool collection
- `PermissionsHandler` - Shared EventStore, permission cache
- `RemindersManager` - Reminder operations
- `CalendarManager` - Calendar operations
- `Logger` - Log configuration
- `JSONRPCHandler` - Encoder/decoder instances

### Sendable Types

All data models conform to `Sendable`:

- `JSONRPCRequest`, `JSONRPCResponse`
- `JSONValue`, `JSONRPCId`, `JSONRPCParams`
- `ToolDefinition`, `ToolResult`
- `Reminder`, `Event`, `Tag`

## Error Handling

### Error Types

```
PermissionError     → JSONRPCError.permissionDenied (-32000)
ReminderError       → JSONRPCError.resourceNotFound (-32001)
                    → JSONRPCError.operationFailed (-32002)
CalendarError       → JSONRPCError.resourceNotFound (-32001)
                    → JSONRPCError.operationFailed (-32002)
ParameterError      → JSONRPCError.invalidParams (-32602)
ToolRegistryError   → JSONRPCError.methodNotFound (-32601)
```

### Error Flow

```
Tool throws error
       │
       ▼
MCPServer catches and maps to JSONRPCError
       │
       ▼
JSONRPCResponse.error created
       │
       ▼
Response encoded and sent to stdout
```

## Design Decisions

### Why Actors?

EventKit operations must be performed on the same EKEventStore instance. Actors ensure:

- Single writer access to mutable state
- Automatic synchronization
- Clear ownership boundaries

This design supports **privacy** (one of our core values) by keeping all data local and properly synchronized.

### Why Separate Domain Models?

EKReminder and EKEvent are:

- Reference types tied to the event store
- Not Sendable
- Have complex relationships

Domain models (Reminder, Event) are:

- Value types
- Sendable
- Include computed properties (tags, duration)
- Optimized for JSON serialization

This separation maintains **data sovereignty** and makes the code more testable.

### Why Tags in Notes — and Why They're Hidden

Apple Reminders has no native tag API, so the GTD/3-3-3 classification is stored
as `#hashtags` in the notes field. Crucially, tags are an **internal** mechanism:

- The user never types or sees them. The connected assistant infers
  classification (`gtd_status` / `effort` / `contexts`, event `categories`) from
  the content, and `TagInference` fills any gaps with keyword heuristics.
- On the way out, notes are returned with hashtags **stripped**; the
  classification is surfaced separately via the `tags` array.
- Storing in notes keeps everything local and means the raw data is still
  recoverable in the native Reminders app if the user looks.

This keeps the surface free of jargon (**reduces cognitive friction**) while the
hidden structure powers the planning tools (**radical clarity**).

### Why stderr for Logging?

MCP protocol uses stdout for JSON-RPC communication. All diagnostic output must go to stderr to avoid corrupting the protocol stream.

## Extension Points

1. Consider: Does this tool reduce cognitive friction? (see [CONSTITUTION.md](CONSTITUTION.md))

### Adding New EventKit Features

1. Add methods to RemindersManager/CalendarManager
2. Update domain models if needed
3. Create/update tool implementations
4. Add tests
5. Document any neurodivergent-specific considerations

### Supporting New MCP Methods

1. Add case to `MCPServer.routeMethod`
2. Implement handler method
3. Update protocol version if needed

## Future Architecture (Phase 1+)

The current architecture is designed to accommodate future enhancements without major refactoring. Note that today's "intelligence" comes from the **connected assistant** (guided by tool schemas, server `instructions`, and the pure `Planner` / `TagInference` engines). The sections below describe heavier, server-resident capabilities that are not yet implemented:

### AI Integration Layer (Phase 1)

- **Location**: New `Sources/Agenda/AI/` directory
- **Components**: Claude API client, prompt templates, context management
- **Integration**: Called by tool implementations before/after EventKit operations
- **Principle**: AI suggests, human decides (see [CONSTITUTION.md](CONSTITUTION.md))

### Learning Layer (Phase 4)

- **Location**: New `Sources/Agenda/Learning/` directory
- **Components**: Pattern recognition, energy prediction, personalization
- **Storage**: Local SQLite database for privacy
- **Privacy**: All learning happens on-device, no telemetry

### User Profile (Phase 2+)

- **Location**: New `Sources/Agenda/Profile/` directory
- **Components**: Preferences, completion history, energy logs
- **Format**: JSON for simple data, SQLite for timeseries
- **Backup**: Exportable by user at any time

See [CONSTITUTION.md](CONSTITUTION.md) for the complete development roadmap and architectural vision.

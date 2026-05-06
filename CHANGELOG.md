# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2024-XX-XX

### Added

- Initial release
- MCP server implementation with JSON-RPC 2.0 protocol
- Reminders integration:
  - `list_reminders` - List reminders with filtering
  - `create_reminder` - Create new reminders
  - `get_reminder` - Get reminder details
  - `update_reminder` - Update existing reminders
  - `complete_reminder` - Mark reminders as complete
  - `delete_reminder` - Delete reminders
  - `list_reminder_lists` - List available reminder lists
- Calendar integration:
  - `list_events` - List calendar events
  - `create_event` - Create new events
  - `get_event` - Get event details
  - `update_event` - Update existing events
  - `delete_event` - Delete events
  - `list_calendars` - List available calendars
- Tag system with #hashtag extraction from notes
- GTD context tags support (#inbox, #next-action, #waiting-on, etc.)
- Natural language date parsing
- Actionable task title validation
- Debug logging mode
- Claude Desktop configuration support

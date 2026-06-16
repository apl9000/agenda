# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-06-16

### Added

- List management tools:
  - `create_reminder_list` - Create a new reminder list
  - `rename_reminder_list` - Rename an existing list
  - `delete_reminder_list` - Delete a list and its reminders
- Move reminders between lists via the `list` parameter on `update_reminder`
- Bulk operations:
  - `complete_reminders` - Complete many reminders in one commit
  - `delete_reminders` - Delete many reminders in one commit
- Opinionated planning tools backed by pure, unit-tested logic:
  - `whats_next` - Recommend the single best next action
  - `plan_my_day` - Build a 3-3-3 day plan (deep work / quick / maintenance)
  - `weekly_review` - GTD-style review of unclarified, stale, waiting, and overdue items
- `check_permissions` tool to check/request Reminders & Calendar access
- 3-3-3 framework tags (`#deep-work`, `#quick-task`, `#maintenance`)
- GitHub Actions CI building and testing on macOS

### Changed

- Rewrote README for publishing (accurate tool list, real repo URLs, deduplicated)

### Fixed

- Removed force-unwraps that violated the project's no-force-unwrap rule
  (`try!` regex in `Tag`, `errors.first!` in `PermissionsHandler`)

## [0.1.0] - 2025-12-17

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

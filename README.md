# Agenda

An opinionated [MCP](https://modelcontextprotocol.io) (Model Context Protocol) server that turns Apple Reminders into a system for actually getting things done. Agenda gives an AI assistant (Claude Desktop, VS Code, etc.) full control of your reminders and calendar, with built-in [GTD](https://gettingthingsdone.com/) structure and a point of view designed to reduce cognitive load — especially for ADHD and dyslexic brains.

## Mission

Build compassionate, neurodivergent-first productivity tools that honor different ways of thinking and working — offering clarity without judgment, structure without pressure, and privacy without compromise. See [CONSTITUTION.md](CONSTITUTION.md) for the full vision.

## What makes it opinionated

Agenda isn't just a thin wrapper over EventKit. On top of full CRUD it adds tools that make a decision *for* you:

- **`whats_next`** — ranks your open reminders by what's overdue, due today, tagged `#next-action`, and high priority, then hands back the *single* best thing to do. Antidote to decision paralysis.
- **`plan_my_day`** — builds a [3-3-3](#the-3-3-3-framework) plan: 3 deep-work items, 3 quick tasks, 3 maintenance items, plus what's overdue and due today.
- **`weekly_review`** — a GTD review that surfaces unclarified tasks, stale `#inbox` items, `#waiting-on` follow-ups, and overdue work so nothing slips.

## Features

- **Full Reminders integration** — create, read, update, complete, delete; move reminders between lists; bulk complete/delete.
- **Full list management** — create, rename, and delete reminder lists.
- **Full Calendar integration** — manage events with natural-language dates.
- **Tag-based GTD** — `#hashtags` in notes drive contexts like `#inbox`, `#next-action`, `#waiting-on`.
- **Opinionated planning** — `whats_next`, `plan_my_day`, `weekly_review`.
- **Natural-language dates** — "tomorrow", "next monday", "in 2 hours".
- **Actionable-task validation** — gentle warnings when a title looks vague.
- **Local-first & private** — all data stays in your Apple account; no telemetry.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (Xcode 15+) to build from source

## Installation

### Build from source

```bash
git clone https://github.com/apl9000/agenda.git
cd agenda
swift build -c release
```

The binary will be at `.build/release/agenda`. Optionally install it:

```bash
sudo cp .build/release/agenda /usr/local/bin/
```

## Configuration

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "agenda": {
      "command": "/usr/local/bin/agenda"
    }
  }
}
```

(Or point `command` at `/path/to/agenda/.build/release/agenda`.)

### VS Code

Configure your MCP settings to launch the `agenda` binary over stdio.

## Permissions

On first use, macOS prompts for access to **Reminders** and **Calendar**. If a tool reports a permission error, run the `check_permissions` tool, then grant access in **System Settings → Privacy & Security → Reminders / Calendars**.

## Available Tools

### Reminders

| Tool                  | Description                                                    |
| --------------------- | ------------------------------------------------------------- |
| `list_reminders`      | List reminders, filtered by list, status, tag, or due date    |
| `create_reminder`     | Create a reminder with title, notes, due date, priority, tags |
| `get_reminder`        | Get full details of a specific reminder                       |
| `update_reminder`     | Update a reminder, including moving it to another list         |
| `complete_reminder`   | Mark a reminder complete                                       |
| `delete_reminder`     | Delete a reminder                                              |
| `complete_reminders`  | Complete many reminders in one call                           |
| `delete_reminders`    | Delete many reminders in one call                             |

### Lists

| Tool                   | Description                              |
| ---------------------- | ---------------------------------------- |
| `list_reminder_lists`  | Get all reminder lists                   |
| `create_reminder_list` | Create a new list                        |
| `rename_reminder_list` | Rename a list                            |
| `delete_reminder_list` | Delete a list and all its reminders      |

### Planning (opinionated)

| Tool            | Description                            |
| --------------- | ------------------------------------- |
| `whats_next`    | Recommend the single best next action |
| `plan_my_day`   | Build a 3-3-3 plan for today          |
| `weekly_review` | GTD-style review of open loops        |

### Calendar

| Tool             | Description                            |
| ---------------- | -------------------------------------- |
| `list_events`    | List events by calendar and date range |
| `create_event`   | Create a new event                     |
| `get_event`      | Get details of a specific event        |
| `update_event`   | Update an event                        |
| `delete_event`   | Delete an event                        |
| `list_calendars` | Get all calendars                      |

### Utility

| Tool                | Description                                 |
| ------------------- | ------------------------------------------- |
| `check_permissions` | Check / request Reminders & Calendar access |

## Usage Examples

```
Create a reminder "Call dentist to schedule cleaning" with tag #next-action due tomorrow
```

```
What should I work on next?
```

```
Plan my day
```

```
Create a list called "Errands", then move the reminder about groceries into it
```

## Tag System

Agenda extracts `#hashtags` from reminder notes automatically — they're visible in the native Reminders app and add no friction.

### GTD context tags

- `#inbox` — uncategorized, needs processing
- `#next-action` — ready to do right now
- `#waiting-on` — blocked on someone else
- `#someday-maybe` — deferred for later
- `#project` — multi-step outcome
- `#reference` — non-actionable reference material

### The 3-3-3 framework

A calm daily structure that `plan_my_day` builds around:

- `#deep-work` — focused, high-energy work (aim for ~3 hours)
- `#quick-task` — under ~15 minutes (aim for 3)
- `#maintenance` — keeps life running (aim for 3)

## Development

```bash
swift build               # build
swift run agenda          # run
swift run agenda --debug  # run with stderr debug logging
swift test                # run tests
swift test --filter PlannerTests  # run one suite
```

The opinionated planning logic in `Sources/Agenda/Utilities/Planner.swift` is pure and fully unit-tested independent of EventKit.

## Documentation

- **[CONSTITUTION.md](CONSTITUTION.md)** — mission, values, and roadmap
- **[ARCHITECTURE.md](ARCHITECTURE.md)** — technical design
- **[CONTRIBUTING.md](CONTRIBUTING.md)** — contributor guidelines
- **[CHANGELOG.md](CHANGELOG.md)** — release history

## Contributing

Contributions are welcome — this project is built *for* the neurodivergent community and values diverse perspectives. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License — see [LICENSE](LICENSE).

## Acknowledgments

- Built on Apple's EventKit framework
- Implements the [Model Context Protocol](https://modelcontextprotocol.io)
- Inspired by GTD (David Allen) and the 3-3-3 framework

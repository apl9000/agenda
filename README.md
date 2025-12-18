# Agenda

An AI-powered MCP (Model Context Protocol) server that transforms Apple Reminders into an intelligent productivity system, specifically designed for people with ADHD and dyslexia. Combines Getting Things Done (GTD) methodology with the 3-3-3 framework to provide executive function support and reduce cognitive load.

## Mission

Build compassionate, neurodivergent-first productivity tools that honor different ways of thinking and working—offering clarity without judgment, intelligence without pressure, and privacy without compromise.

## Features

### Current (Phase 0)

- **Full Reminders Integration**: Create, update, complete, and delete reminders
- **Full Calendar Integration**: Manage calendar events with natural language date parsing
- **Tag Support**: Extract and manage #hashtags from reminder notes
- **GTD Ready**: Built-in support for GTD contexts (#inbox, #next-action, #waiting-on, etc.)
- **Natural Language Dates**: "tomorrow", "next monday", "in 2 hours"
- **Actionable Task Validation**: Warns about vague or non-actionable task titles

### Coming Soon (Phase 1+)

- **AI-Powered Clarification**: Automatically detect and help clarify vague tasks
- **Energy Level Tracking**: Match tasks to your current energy state
- **3-3-3 Daily Planning**: Structure your day with 3 deep work hours, 3 short tasks, 3 maintenance items
- **Pattern Learning**: System learns your rhythms and preferences over time
- **Executive Function Support**: Built-in support for ADHD challenges like time blindness and task initiation

See [CONSTITUTION.md](CONSTITUTION.md) for the complete vision and roadmap.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+
- Xcode 15+ (for building)

## Installation

### Build from Source

```bash
git clone https://github.com/yourusername/agenda.git
cd agenda
swift build -c release
```

The binary will be at `.build/release/agenda`.

### Install to /usr/local/bin

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

Or if using the build directory:

```json
{
  "mcpServers": {
    "agenda": {
      "command": "/path/to/agenda/.build/release/agenda"
    }
  }
}
```

### VS Code

Configure in your VS Code MCP settings to point to the agenda binary.

## Permissions

On first use, macOS will prompt for access to:

- **Reminders**: Required for reminder functionality
- **Calendar**: Required for calendar functionality

Grant access in **System Settings > Privacy & Security > Reminders/Calendars**.

## Available Tools

### Reminders

| Tool                  | Description                                                   |
| --------------------- | ------------------------------------------------------------- |
| `list_reminders`      | List reminders with filtering by list, status, tags, due date |
| `create_reminder`     | Create a new reminder with title, notes, due date, priority   |
| `get_reminder`        | Get full details of a specific reminder                       |
| `update_reminder`     | Update an existing reminder                                   |
| `complete_reminder`   | Mark a reminder as complete                                   |
| `delete_reminder`     | Delete a reminder                                             |
| `list_reminder_lists` | Get all available reminder lists                              |

### Calendar

| Tool             | Description                                           |
| ---------------- | ----------------------------------------------------- |
| `list_events`    | List events with filtering by calendar and date range |
| `create_event`   | Create a new calendar event                           |
| `get_event`      | Get full details of a specific event                  |
| `update_event`   | Update an existing event                              |
| `delete_event`   | Delete an event                                       |
| `list_calendars` | Get all available calendars                           |

## Usage Examples

### List Today's Reminders

```
Use list_reminders to show incomplete reminders due today
```

### Create a Reminder with GTD Tag

```
Create a reminder "Call dentist to schedule appointment" with tag #next-action due tomorrow
```

### Show This Week's Events

````🏷️ Tag System

Agenda extracts #hashtags from reminder notes automatically. The tag system is designed to support both GTD methodology and ADHD-friendly workflows:

### GTD Phase Tags
- `#inbox` - Uncategorized items needing processing
- `#clarify` - Needs to be made more actionable
- `#next-action` - Ready to be done right now
- `#waiting-on` - Blocked on someone else
- `#someday-maybe` - Deferred for later
- `#project` - Multi-step outcomes
- `#reference` - Non-actionable reference material

### 3-3-3 Framework Tags
- `#deep-work` - Requires focused, creative energy (aim for 3 hours daily)
- `#quick-task` - Can be done in < 15 minutes (aim for 3 daily)
- `#maintenance` - Keeps life running smoothly (aim for 3 daily)

### Context Tags
- `#computer` - Requires a computer
- `#home` - Can only be done at home
- `#errands` - Out-and-about tasks
- `#short-call` - Quick phone call

### Energy Tags
- `#flow-time` - Best during peak focus hours
- `#low-energy` - Good for tired times

See [CONSTITUTION.md](CONSTITUTION.md) for more details on the tag system philosophy.
## Tag System

Agenda extracts #hashtags from reminder notes automatically. Standard GTD tags:

- `#inbox` - Uncategorized items needing processing
- `#next-action` - Ready to be done
- `#waiting-on` - Blocked on someone else
- `#someday-maybe` - Deferred for later
- `#project` - Multi-step outcomes
- `#reference` - Non-actionable reference material

## Development

### Build

```bash
swift build
````

## Core Values

Agenda is built on five core values:

1. **Neurodivergent-First Design** - Every feature evaluated through the lens of ADHD and dyslexia needs
2. **Radical Clarity** - Tasks must be concrete and actionable, no vague language
3. **Compassionate Intelligence** - AI that encourages, not judges
4. **Privacy & Control** - All data stays on device, you own everything
5. **Interoperability** - Works seamlessly with the Apple ecosystem

Read the full [CONSTITUTION.md](CONSTITUTION.md) to understand our mission and principles.

## Documentation

- **[CONSTITUTION.md](CONSTITUTION.md)** - Mission, values, and product roadmap
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical design and implementation details
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Guidelines for contributors

## Contributing

Contributions are welcome! This project is built _for_ the neurodivergent community, and we value diverse perspectives.

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines, and [CONSTITUTION.md](CONSTITUTION.md) to understand the project's core principl

### Run with Debug Logging

```bash
swift run agenda --debug
```

### Test

```bash
swift test
```

## Architecture

See [ARCHITECTURE.md](ARCHITECTURE.md) for technical design details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- Built on Apple's EventKit framework
- Implements the [Model Context Protocol](https://modelcontextprotocol.io) specification
- Inspired by GTD methodology by David Allen

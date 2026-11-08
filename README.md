# Agenda

An opinionated [MCP](https://modelcontextprotocol.io) (Model Context Protocol) server that turns Apple Reminders into a system for actually getting things done. Agenda gives an AI assistant (Claude Desktop, VS Code, etc.) full control of your reminders and calendar, with built-in [GTD](https://gettingthingsdone.com/) structure and a point of view designed to reduce cognitive load — especially for ADHD and dyslexic brains.

## Mission

Build compassionate, neurodivergent-first productivity tools that honor different ways of thinking and working — offering clarity without judgment, structure without pressure, and privacy without compromise.

## What makes it opinionated

Agenda isn't just a thin wrapper over EventKit. On top of full CRUD it adds tools that make a decision *for* you:

- **`whats_next`** — ranks your open reminders by what's overdue, due today, marked as a next action, and high priority, then hands back the *single* best thing to do. Antidote to decision paralysis.
- **`plan_my_day`** — builds a [3-3-3](#organization-you-never-type-a-tag) plan: 3 deep-work items, 3 quick tasks, 3 maintenance items, plus what's overdue and due today.
- **`weekly_review`** — a GTD review that surfaces unclarified tasks, stale inbox items, waiting-on follow-ups, and overdue work so nothing slips.

## Features

- **Full Reminders integration** — create, read, update, complete, delete; move reminders between lists; bulk complete/delete.
- **Full list management** — create, rename, and delete reminder lists.
- **Full Calendar integration** — manage events with natural-language dates.
- **Automatic GTD organization** — the assistant infers GTD status, effort, and contexts from what you say; you never learn or type a tag.
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
      "command": "/absolute/path/to/agenda/.build/release/agenda"
    }
  }
}
```

`command` **must be an absolute path to a binary that exists** — `~` is not
expanded and relative paths won't work. Use the full path printed by
`echo "$(pwd)/.build/release/agenda"` from the repo, or `/usr/local/bin/agenda`
only if you ran the optional `sudo cp` install step above.

After editing the config, **fully quit Claude Desktop** (⌘Q — closing the window
isn't enough) and reopen it.

#### If Agenda doesn't show up

1. Confirm the binary works on its own — it should print an `initialize` response:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"t","version":"1"}}}' | .build/release/agenda
   ```
2. Check Claude's MCP logs: `~/Library/Logs/Claude/mcp.log` and
   `~/Library/Logs/Claude/mcp-server-agenda.log`.
3. Make sure the JSON is valid (no trailing commas) and the path is absolute.

### VS Code

Configure your MCP settings to launch the `agenda` binary over stdio.

## Permissions

Agenda calls EventKit `requestFullAccessToReminders` and `requestFullAccessToEvents`. Those APIs need usage strings in the calling process's Info.plist (`NSRemindersFullAccessUsageDescription`, `NSCalendarsFullAccessUsageDescription`, and the legacy `NSRemindersUsageDescription` / `NSCalendarsUsageDescription` keys). The release binary embeds `Sources/Agenda/Info.plist` in the Mach-O section `__TEXT,__info_plist` so EventKit can read them. Check that section with:

```bash
otool -s __TEXT __info_plist .build/release/agenda
```

`swift build -c release` linker-signs the executable. That signature does not bind `__TEXT,__info_plist`. On macOS 26.5.1 arm64, `otool -P` printed the usage strings while `codesign -dv` reported `Signature=adhoc`, linker-signed, `Identifier=agenda`, and `Info.plist=not bound`. The macos-15 CI runner reported `Info.plist=not bound` on that same linker-signed binary. Re-sign after the link:

```bash
make sign-adhoc
# or: ./Scripts/sign-adhoc.sh .build/release/agenda
# codesign --force --sign - --identifier cloud.rives.agenda <binary>
```

`make release` builds and then runs that script. The identity is `-` (ad-hoc). No Developer ID. CI runs the script and then checks that `codesign -dv` reports `Identifier=cloud.rives.agenda` and a bound Info.plist (`Info.plist entries=`, and not `Info.plist=not bound`). On the macos-15 runner, that check passed after `Scripts/sign-adhoc.sh` (the verify step printed `embedded Info.plist ok` before the unit tests compiled). Ad-hoc `codesign` can bind the embedded plist on that runner.

On that macOS 26.5.1 run, before this re-sign, `check_permissions` reported `notDetermined` for Reminders and Calendar, with a full-access request attempted, `requestGranted` false, no `requestError`, and no dialog. This repository has not repeated that EventKit call after `Scripts/sign-adhoc.sh`, so the re-sign is not claimed to make the dialog appear.

macOS attributes the prompt to the responsible process, which for a program launched by another app is that launching app, not a separate row named Agenda. Tor Arne Vestbø's account, quoted by Michael Tsai, is that TCC picks the responsible process and that a usage-description key required by a child has to be in the responsible app ([The Curious Case of the Responsible Process](https://mjtsai.com/blog/2025/07/07/the-curious-case-of-the-responsible-process/)). Howard Oakley describes the same attribution chain for shell commands: TCC walks up to a GUI app such as Terminal, and that app hosts the dialog ([Code signing for the concerned: 5 Signing and privacy control](https://eclecticlight.co/2019/01/29/code-signing-for-the-concerned-5-signing-and-privacy-control/)). Those sources do not say that an ad-hoc signature on the CLI makes the CLI the responsible process when a GUI app spawned it. The controls for the responsible app are:

- **System Settings → Privacy & Security → Calendars**
- **System Settings → Privacy & Security → Reminders**

`codesign(1)` says that if `--identifier` is omitted, the identifier is taken from the Info.plist when one is present, otherwise from the filename ([codesign(1)](https://keith.github.io/xcode-man-pages/codesign.1.html)). The linker-signed binary did not do that — its identifier stayed `agenda` while the plist said `cloud.rives.agenda` — which matches `Info.plist=not bound`. The sign script passes `--identifier` explicitly.

`check_permissions` (and `agenda --check-permissions`) reports, for Reminders and for Calendar separately:

- `status` — the EventKit authorization status: `notDetermined`, `restricted`, `denied`, `fullAccess`, `writeOnly`, or `authorized`
- `statusRawValue` — that status's raw value
- `requestAttempted` — whether a full-access request was made (only when the status was `notDetermined`)
- `requestGranted` — the boolean the request returned, or `null` if it was not attempted or it threw
- `requestError` — `domain`, `code`, and `description` when the request threw

A request that returns false, or throws, does not change `status` into `denied`. `notDetermined`, `restricted`, `denied`, and a failed request stay distinct. The command prints that JSON on stdout and exits. It does not list events or reminders. Stderr from a failed request contains the entity name, the error domain, and the error code.

```bash
.build/release/agenda --check-permissions
```

This was not reproduced end to end against a particular host app in CI. Read the JSON from a run on your machine; do not treat a missing dialog as a recorded denial unless `status` is `denied`.

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
| `check_permissions` | Report Reminders and Calendar authorization, and request access only when it is `notDetermined` |

## Usage Examples

You just talk normally — Agenda figures out the organization.

```
Remind me to call the dentist to schedule a cleaning tomorrow
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

## Organization (you never type a tag)

Agenda organizes your reminders and events for you. **You never have to learn or type a tag.** When you ask the assistant to add something, it infers the classification from what you said, and Agenda fills in anything it missed with built-in heuristics. The classification is stored invisibly (as `#hashtags` in notes, which the tools strip from what you see) and powers `whats_next`, `plan_my_day`, and `weekly_review`.

Under the hood, reminders are classified by:

- **GTD status** — `inbox`, `next-action`, `waiting-on`, `someday-maybe`, `project`, `reference`
- **Effort (3-3-3)** — `deep-work`, `quick-task`, `maintenance`
- **Contexts** — where/how it gets done, e.g. `errands`, `calls`, `home`, `computer`, `finance`, `health`

Events are classified by **categories** (e.g. `work`, `health`, `social`, `travel`, `personal`).

You can still steer it ("make this a someday-maybe", "that's deep work") — but you never have to.

## Development

```bash
swift build               # build
swift run agenda          # run
swift run agenda --debug  # run with stderr debug logging
swift run agenda --check-permissions  # print authorization JSON and exit
swift test                # run tests
swift test --filter PlannerTests  # run one suite
```

The opinionated planning logic in `Sources/Agenda/Utilities/Planner.swift` is pure and fully unit-tested independent of EventKit.

`Package.swift` passes `-sectcreate __TEXT __info_plist` through `linkerSettings` `unsafeFlags`, which is the Package.swift API that can pass that flag. A target using `unsafeFlags` cannot be a dependency of another package. The Info.plist path is absolute (`#filePath`) because the linker opens it from the build's working directory. The file is excluded from the target so SwiftPM does not treat it as a bundle resource. After `swift build -c release`, run `make sign-adhoc` (see above). CI does that, then runs `otool -s __TEXT __info_plist` against `.build/release/agenda` and checks the usage-description keys and the ad-hoc signature. Hosted `macos-14` runners stopped scheduling on 2026-11-02, so that job runs on `macos-15`. The package deployment target is still macOS 14.

## Documentation

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

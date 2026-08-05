# Contributing to Agenda

Thank you for your interest in contributing to Agenda! This project is built _for_ the neurodivergent community, and we deeply value diverse perspectives and lived experiences.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions. We're building tools to support people, not judge them. Approach contributions with compassion and curiosity.

## Our Mission

Agenda is guided by these core values:

- **Neurodivergent-First Design** - ADHD and dyslexia needs drive every decision
- **Radical Clarity** - Clear, actionable, no vague language
- **Compassionate Intelligence** - AI that encourages, never judges
- **Privacy & Control** - User data stays local and secure
- **Interoperability** - Works seamlessly with existing tools

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/apl9000/agenda.git`
3. Create a feature branch: `git checkout -b feature/your-feature`
4. Make your changes
5. Run tests: `swift test`
6. Commit your changes with a descriptive message
7. Push to your fork and submit a pull request

## Development Setup

### Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+
- Swift 5.9+

### Building

```bash
swift build
```

### Running Tests

```bash
swift test
```

### Running Locally

```bash
swift run agenda --debug
```

## Code Style

### Swift Guidelines

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use `async/await` for asynchronous code
- Prefer value types (structs) over reference types (classes) where appropriate
- Use actors for thread-safe mutable state
- Add DocC documentation comments for all public APIs

### Error Handling

- Never use force unwrap (`!`) or `try!`
- Create specific error types for different failure modes
- Provide helpful error messages that guide users to solutions
- Map errors to appropriate JSON-RPC error codes

### Naming

- Use clear, descriptive names
- Prefix protocols with a noun describing what they do
- Use verbs for methods that perform actions
- Use nouns for properties and types

## Architecture

The server is structured in three layers — MCP protocol (`Sources/Agenda/MCP/`), tool implementations (`Sources/Agenda/Tools/`), and EventKit wrappers (`Sources/Agenda/EventKit/`) — with pure, EventKit-free engines in `Sources/Agenda/Utilities/` (`Planner`, `TagInference`).

### Key Principles

1. **Separation of Concerns**: Keep MCP protocol handling, EventKit integration, and domain logic in separate layers
2. **Protocol-Oriented Design**: Use protocols for testability and flexibility
3. **Immutability**: Prefer immutable data structures
4. **Fail Gracefully**: Never crash; always return proper error responses
5. **Reduce Cognitive Friction**: Every feature should make tasks _easier_ to manage, not harder
6. **Local-First**: Prioritize on-device processing and storage for privacy

## Testing

### Unit Tests

- Write tests for all new functionality
- Aim for 80%+ code coverage
- Keep opinionated logic in pure, EventKit-free engines (e.g. `Planner`,
  `TagInference`, `DateHelpers`, `Tag`) so it can be tested directly — this is
  preferred over mocking EventKit
- Every push and PR is built and tested on macOS by GitHub Actions
  (`.github/workflows/ci.yml`); make sure `swift build` and `swift test` pass locally first

### Integration Tests

- Test actual EventKit integration separately
- These tests require system permissions and run on a real macOS machine

## Pull Request Process

1. Update documentation if you're changing public APIs
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md with your changes
5. Request review from maintainers

### PR Title Format

Use conventional commit format:

- `feat: add new feature`
- `fix: fix bug in reminder creation`
- `docs: update README`
- `refactor: restructure tool registry`
- `test: add tests for calendar manager`

## Reporting Issues

When reporting issues, please include:

1. macOS version
2. Swift version (`swift --version`)
3. Steps to reproduce
4. Expected behavior
5. Actual behavior
6. Relevant log output (run with `--debug`)

## Feature Requests

Feature requests are welcome! Please:

1. Check existing issues for duplicates
2. Describe the use case
3. Explain why this would benefit users
4. Consider the GTD/neurodivergent user focus

## Neurodivergent Contributors

If you have ADHD, dyslexia, or other neurodivergent traits:

- **Your perspective is invaluable** - You understand the problems we're solving
- **Take your time** - No pressure on response times or contribution pace
- **Ask questions** - Clarification requests are always welcome
- **Small contributions matter** - Bug reports, documentation fixes, and user stories are all valuable

## Accessibility

We strive to make the contribution process accessible:

- Clear, structured documentation
- Code examples for complex concepts
- Welcoming to questions
- Patient with different communication styles

## Questions?

Open a discussion or issue on GitHub. We're here to help!

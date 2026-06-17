# Constitution: Agenda MCP Server

**Project Name:** Agenda  
**Version:** 0.2.0  
**Created:** December 17, 2025  
**Last Updated:** June 17, 2026  
**Status:** Active — 0.2.0 shipped (see Roadmap)

---

## Mission Statement

Build an AI-powered Model Context Protocol (MCP) server that transforms Apple Reminders into an intelligent productivity system, specifically designed for people with ADHD and dyslexia. The system combines Getting Things Done (GTD) methodology with the 3-3-3 framework, enhanced by AI to provide executive function support, reduce cognitive load, and create sustainable productivity habits.

---

## Core Values

### 1. **Neurodivergent-First Design**

- Every feature is evaluated through the lens of ADHD and dyslexia needs
- Reduce cognitive friction, not add to it
- Honor different ways of thinking and working
- No shame, only support

### 2. **Radical Clarity**

- Tasks must be concrete and actionable
- No vague language that creates analysis paralysis
- Every reminder should pass the "can I do this right now?" test
- Context is king

### 3. **Compassionate Intelligence**

- AI that encourages, not judges
- Learns your patterns without being pushy
- Respects executive dysfunction as real
- Celebrates progress over perfection

### 4. **Privacy & Control**

- All data stays on device when possible
- User controls what gets analyzed
- Transparent about AI processing
- No tracking or surveillance

### 5. **Interoperability**

- Works with existing Apple ecosystem
- Plays well with other tools
- Export your data anytime
- Open protocols (MCP)

---

## Architectural Principles

### Technical Philosophy

1. **Swift-First, Native Experience**

   - Leverage EventKit for seamless Apple integration
   - Native performance and reliability
   - System-level integration (Shortcuts, Widgets)

2. **AI as Augmentation, Not Replacement**

   - AI suggests, human decides
   - Preserve user agency
   - Learn from user feedback
   - Graceful degradation when AI unavailable

3. **Incremental Complexity**

   - Start simple, add sophistication gradually
   - Each layer should work independently
   - No big-bang releases
   - Test with real users continuously

4. **Data Sovereignty**
   - Local-first architecture
   - Cloud sync optional
   - Encrypted when stored remotely
   - User owns all training data

---

## System Architecture

```
┌─────────────────────────────────────────────────────┐
│                MCP Server Layer                      │
│  - JSON-RPC Protocol Implementation                  │
│  - Tool Registration & Dispatch                      │
│  - Error Handling & Logging                          │
└─────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┴─────────────────┐
        │                                   │
┌───────▼──────────┐              ┌────────▼──────────┐
│  EventKit Layer  │              │   AI Engine       │
│  - Reminders     │              │   - Claude API    │
│  - Calendars     │              │   - Prompt Mgmt   │
│  - Lists         │              │   - Context Cache │
└───────┬──────────┘              └────────┬──────────┘
        │                                   │
┌───────▼───────────────────────────────────▼─────────┐
│           Intelligence & Learning Layer              │
│  - Pattern Recognition                               │
│  - Time Estimation Models                            │
│  - Energy Level Prediction                           │
│  - Tag Recommendation Engine                         │
│  - Natural Language Processing                       │
└───────┬──────────────────────────────────────────────┘
        │
┌───────▼──────────────────────────────────────────────┐
│              User Profile & Persistence               │
│  - Preferences (JSON/SQLite)                          │
│  - Task History                                       │
│  - Completion Patterns                                │
│  - Energy Logs                                        │
│  - Custom Tag Definitions                             │
└──────────────────────────────────────────────────────┘
```

---

## Design Principles

### User Experience

1. **Friction-Free Capture**

   - Add tasks in seconds
   - Voice-first when possible
   - Natural language everywhere
   - No mandatory fields

2. **Intelligent Defaults**

   - AI suggests tags, times, contexts
   - One-tap acceptance
   - Easy to override
   - Learns from corrections

3. **Calm Technology**

   - Notifications are helpful, not nagging
   - Respect focus time
   - Gentle reminders only
   - User controls frequency

4. **Visual Hierarchy**
   - Most important = most visible
   - Color coding for energy levels
   - Icons for quick scanning
   - Dyslexia-friendly typography

### Data Model

**Core Entities:**

- **Task**: Atomic unit of work
- **Project**: Collection of related tasks
- **Context**: Where/when/with what
- **Tag**: Categorization + metadata
- **Session**: Work period with start/end
- **Pattern**: Learned behavior or preference

**Tag System (from Charter):**

- GTD Phase: #inbox, #clarify, #next-action, #waiting-on, etc.
- 3-3-3 Category: #deep-work, #quick-task, #maintenance
- Context: #computer, #home, #short-call
- Energy: #flow-time, #low-energy
- Lifecycle: #someday-maybe, #reference

---

## Development Roadmap

### Phase 0: Foundation (Complete)

**Goal:** Basic MCP server that can CRUD reminders

- [x] Swift project setup with SPM
- [x] MCP protocol implementation
- [x] EventKit integration
- [x] Basic reminder operations (list, create, update, delete)
- [x] Configuration file support
- [x] Testing infrastructure
- [x] Continuous integration (build + test on macOS)

**Status:** Complete.

---

### Phase 0.5: Productivity & Organization (Delivered in 0.2.0)

**Goal:** Make Agenda a genuinely opinionated, fully-featured Reminders system

- [x] Full Reminders support: list management (create/rename/delete), move
  reminders between lists, bulk complete/delete
- [x] Opinionated planning tools: `whats_next`, `plan_my_day` (3-3-3),
  `weekly_review` — backed by the pure, tested `Planner`
- [x] Automatic tag inference: the assistant classifies items (`gtd_status` /
  `effort` / `contexts`, event `categories`) and the `TagInference` engine fills
  gaps; users never see or type a tag, and notes are returned without hashtags
- [x] MCP server `instructions` that drive the assistant's classification

**Status:** Shipped. Pulls several items forward from Phase 3 below.

---

### Phase 1: Intelligence Layer (Planned)

**Goal:** AI-powered task understanding

- [ ] Claude API integration for task clarification
- [ ] Prompt templates for task breakdown
- [ ] Natural language parsing enhancement
- [ ] Vague task detection
- [ ] Auto-clarification questions
- [ ] Time estimation (basic)

**Deliverable:** AI that makes tasks actionable

---

### Phase 2: ADHD Features (Planned)

**Goal:** Executive function support

- [ ] Energy level tracking
- [x] Task recommendation by context (`whats_next`)
- [ ] Time-of-day suggestions
- [ ] Break reminders
- [ ] Dopamine-friendly encouragement
- [ ] Pattern recognition

**Deliverable:** System that understands your rhythm

---

### Phase 3: 3-3-3 Framework (Planned)

**Goal:** Structured daily workflow

- [x] Daily planning assistant (`plan_my_day`)
- [ ] 3 hours deep work scheduling (auto-scheduling to calendar)
- [x] 3 short tasks identification (`plan_my_day` quick-task bucket)
- [x] 3 maintenance items tracking (`plan_my_day` maintenance bucket)
- [ ] Progress tracking dashboard
- [x] Weekly review prompts (`weekly_review`)

**Deliverable:** Sustainable daily structure (core delivered in 0.2.0; scheduling + dashboard remain)

---

### Phase 4: Learning & Adaptation (Future)

**Goal:** System that learns from you

- [ ] Completion pattern analysis
- [ ] Energy prediction models
- [ ] Task duration learning
- [ ] Context inference
- [ ] Personalized suggestions
- [ ] Trend visualization

**Deliverable:** Personal productivity insights

---

## Quality Standards

### Code Quality

- **Test Coverage**: 80%+ for business logic
- **Documentation**: All public APIs documented
- **Error Handling**: No force unwraps, proper error propagation
- **Type Safety**: Leverage Swift's type system fully
- **Async/Await**: All I/O operations async

### User Experience

- **Response Time**: Tool calls complete in < 2 seconds
- **Clarity**: Error messages explain what happened and what to do
- **Accessibility**: Screen reader support, keyboard navigation
- **Reliability**: Graceful degradation when services unavailable

### AI Behavior

- **Helpfulness**: Suggestions improve task clarity
- **Non-Intrusive**: Never blocks user action
- **Transparent**: User knows when AI is involved
- **Correctable**: Easy to override AI suggestions
- **Learning**: Gets better with user feedback

---

## Technical Constraints

### Platform

- **macOS 14.0+**: Required for EventKit features
- **Swift 5.9+**: Modern concurrency features
- **EventKit**: Apple's APIs, their limitations apply
- **MCP Protocol**: Must conform to specification

### Performance

- **Memory**: < 100MB typical usage
- **CPU**: Background process, minimal impact
- **I/O**: Batch operations when possible
- **Network**: Optional, for AI features only

### Security

- **Sandboxing**: Run with minimal permissions
- **Encryption**: All remote data encrypted
- **Authentication**: Secure token storage
- **Audit**: All AI queries logged locally

---

## Key Concepts

### GTD Integration

Getting Things Done methodology provides the foundation:

- **Capture**: Quick inbox for all inputs
- **Clarify**: Is it actionable? What's the next action?
- **Organize**: Sort by context, priority, project
- **Reflect**: Regular reviews to stay current
- **Engage**: Do the work with confidence

### 3-3-3 Framework

Daily structure for ADHD minds:

- **3 Hours Deep Work**: Focused, creative, high-energy tasks
- **3 Short Tasks**: Quick wins, momentum builders
- **3 Maintenance Items**: Keep life running smoothly

Combined with GTD tags, creates a balanced daily plan.

### ADHD-Specific Design

Features addressing executive dysfunction:

- **Working Memory**: Capture everything immediately
- **Task Initiation**: Make starting as easy as possible
- **Time Blindness**: Visual time tracking and estimates
- **Hyperfocus**: Honor flow states, don't interrupt
- **Dopamine**: Celebrate wins, make progress visible
- **Rejection Sensitivity**: Kind language, no judgment

---

## References

### Methodology

- **GTD**: _Getting Things Done_ by David Allen
- **3-3-3**: Productivity framework for daily planning
- **ADHD Research**: Clinical understanding of executive function

### Technical

- **MCP Protocol**: [Model Context Protocol Specification](https://modelcontextprotocol.io)
- **EventKit**: [Apple EventKit Documentation](https://developer.apple.com/documentation/eventkit)
- **Swift Concurrency**: [Swift Async/Await](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)

### Design

- **Calm Technology**: Principles by Amber Case
- **Dyslexia-Friendly Design**: British Dyslexia Association guidelines
- **Accessible Design**: Apple Human Interface Guidelines

---

## Community Guidelines

### For Contributors

- **Read First**: [CONTRIBUTING.md](CONTRIBUTING.md) for code guidelines
- **Understand**: This constitution defines what we build and why
- **Question**: Challenge decisions, but through the lens of our values
- **Test**: With neurodivergent users, not assumptions

### For Users

- **Feedback Welcome**: Your experience shapes the product
- **Privacy First**: We never see your data without permission
- **Open Source**: Code is transparent, auditable, forkable
- **Community**: Share tips, strategies, and workflows

---

## Living Document

This constitution is versioned with the project. Major changes require:

1. Discussion in GitHub Issues
2. Pull request with rationale
3. Community review period
4. Maintainer approval

**Current Version**: 0.2.0  
**Last Updated**: June 17, 2026  
**Next Review**: Q3 2026

---

## Contact & Support

- **GitHub**: [github.com/apl9000/agenda](https://github.com/apl9000/agenda)
- **Issues**: Bug reports and feature requests
- **Discussions**: Questions and community support
- **Email**: For private/security matters only

---

_Built with care for the neurodivergent community._

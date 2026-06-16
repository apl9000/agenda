import Foundation

/// Opinionated prioritization and planning logic for reminders.
///
/// These functions are intentionally pure (no EventKit dependency) so the
/// "get-it-done" behavior can be reasoned about and unit-tested in isolation.
/// They encode Agenda's point of view: surface what is overdue or due today,
/// honor explicit next actions, and gently defer `#someday-maybe` / `#waiting-on`.
public enum Planner {

    // MARK: - Next Action Ranking

    /// Ranks incomplete reminders by how good a "next action" each one is.
    ///
    /// Higher-scoring reminders come first. Completed reminders are excluded.
    ///
    /// - Parameters:
    ///   - reminders: The reminders to rank.
    ///   - now: The reference time (injectable for testing).
    /// - Returns: Incomplete reminders ordered best-first.
    public static func rankNextActions(_ reminders: [Reminder], now: Date = Date()) -> [Reminder] {
        reminders
            .filter { !$0.isCompleted }
            .sorted { lhs, rhs in
                let lScore = score(lhs, now: now)
                let rScore = score(rhs, now: now)
                if lScore != rScore {
                    return lScore > rScore
                }
                // Tie-break: soonest due date first, then alphabetically by title.
                switch (lhs.dueDate, rhs.dueDate) {
                case (let l?, let r?) where l != r:
                    return l < r
                case (nil, _?):
                    return false
                case (_?, nil):
                    return true
                default:
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
            }
    }

    /// Scores a single reminder for next-action ranking.
    ///
    /// Exposed internally so the weighting can be unit-tested directly.
    static func score(_ reminder: Reminder, now: Date) -> Int {
        var score = 0
        let calendar = Calendar.current

        if let due = reminder.dueDate {
            if due < calendar.startOfDay(for: now) {
                score += 1000          // overdue
            } else if calendar.isDateInToday(due) {
                score += 500           // due today
            } else {
                score += 100           // scheduled for later
            }
        }

        if reminder.tags.contains(.nextAction) {
            score += 250
        }

        switch reminder.priorityLevel {
        case .high: score += 60
        case .medium: score += 40
        case .low: score += 20
        case .none: score += 0
        }

        // Deliberately push deferred / blocked work down the list.
        if reminder.tags.contains(.somedayMaybe) {
            score -= 500
        }
        if reminder.tags.contains(.waitingOn) {
            score -= 300
        }

        return score
    }

    // MARK: - Daily 3-3-3 Plan

    /// Builds a structured day from incomplete reminders using the 3-3-3 framework.
    ///
    /// - Parameters:
    ///   - reminders: The reminders to plan from.
    ///   - now: The reference time (injectable for testing).
    /// - Returns: A `DayPlan` describing the recommended shape of the day.
    public static func planDay(_ reminders: [Reminder], now: Date = Date()) -> DayPlan {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)

        let ranked = rankNextActions(reminders, now: now)

        let overdue = ranked.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due < startOfToday
        }

        let dueToday = ranked.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return calendar.isDateInToday(due)
        }

        let deepWork = Array(ranked.filter { $0.tags.contains(.deepWork) }.prefix(3))
        let quickTasks = Array(ranked.filter { $0.tags.contains(.quickTask) }.prefix(3))
        let maintenance = Array(ranked.filter { $0.tags.contains(.maintenance) }.prefix(3))

        return DayPlan(
            focus: ranked.first,
            overdue: overdue,
            dueToday: dueToday,
            deepWork: deepWork,
            quickTasks: quickTasks,
            maintenance: maintenance
        )
    }

    // MARK: - Weekly Review

    /// Produces a GTD-style review of the inbox and open loops.
    ///
    /// - Parameters:
    ///   - reminders: The reminders to review.
    ///   - now: The reference time (injectable for testing).
    ///   - staleAfterDays: How old an `#inbox` item must be to count as stale.
    /// - Returns: A `ReviewReport` grouping items that need attention.
    public static func review(
        _ reminders: [Reminder],
        now: Date = Date(),
        staleAfterDays: Int = 7
    ) -> ReviewReport {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let staleCutoff = calendar.date(byAdding: .day, value: -staleAfterDays, to: now) ?? now

        let open = reminders.filter { !$0.isCompleted }

        // Items with no GTD context tag at all — they have not been clarified.
        let unclarified = open.filter { reminder in
            reminder.tags.allSatisfy { !$0.isGTDContext }
        }

        let staleInbox = open.filter { reminder in
            guard reminder.tags.contains(.inbox), let created = reminder.createdDate else {
                return false
            }
            return created < staleCutoff
        }

        let waitingOn = open.filter { $0.tags.contains(.waitingOn) }

        let overdue = open.filter { reminder in
            guard let due = reminder.dueDate else { return false }
            return due < startOfToday
        }

        let somedayMaybe = open.filter { $0.tags.contains(.somedayMaybe) }

        return ReviewReport(
            unclarified: unclarified,
            staleInbox: staleInbox,
            waitingOn: waitingOn,
            overdue: overdue,
            somedayMaybe: somedayMaybe
        )
    }
}

// MARK: - Day Plan

/// A structured plan for the day following the 3-3-3 framework.
public struct DayPlan: Sendable {
    /// The single best next action to start with, if any.
    public let focus: Reminder?
    /// Reminders whose due date is before today.
    public let overdue: [Reminder]
    /// Reminders due today.
    public let dueToday: [Reminder]
    /// Up to three `#deep-work` items.
    public let deepWork: [Reminder]
    /// Up to three `#quick-task` items.
    public let quickTasks: [Reminder]
    /// Up to three `#maintenance` items.
    public let maintenance: [Reminder]

    public init(
        focus: Reminder?,
        overdue: [Reminder],
        dueToday: [Reminder],
        deepWork: [Reminder],
        quickTasks: [Reminder],
        maintenance: [Reminder]
    ) {
        self.focus = focus
        self.overdue = overdue
        self.dueToday = dueToday
        self.deepWork = deepWork
        self.quickTasks = quickTasks
        self.maintenance = maintenance
    }

    /// Converts the plan to a JSONValue for MCP responses.
    public func toJSONValue() -> JSONValue {
        var dict: [String: JSONValue] = [
            "overdue": .array(overdue.map { $0.toJSONValue() }),
            "dueToday": .array(dueToday.map { $0.toJSONValue() }),
            "deepWork": .array(deepWork.map { $0.toJSONValue() }),
            "quickTasks": .array(quickTasks.map { $0.toJSONValue() }),
            "maintenance": .array(maintenance.map { $0.toJSONValue() })
        ]
        if let focus = focus {
            dict["focus"] = focus.toJSONValue()
        }
        return .object(dict)
    }
}

// MARK: - Review Report

/// A GTD-style review grouping reminders that need attention.
public struct ReviewReport: Sendable {
    /// Open reminders with no GTD context tag (not yet clarified).
    public let unclarified: [Reminder]
    /// `#inbox` items older than the staleness threshold.
    public let staleInbox: [Reminder]
    /// `#waiting-on` items to follow up on.
    public let waitingOn: [Reminder]
    /// Overdue reminders.
    public let overdue: [Reminder]
    /// `#someday-maybe` items to reconsider.
    public let somedayMaybe: [Reminder]

    public init(
        unclarified: [Reminder],
        staleInbox: [Reminder],
        waitingOn: [Reminder],
        overdue: [Reminder],
        somedayMaybe: [Reminder]
    ) {
        self.unclarified = unclarified
        self.staleInbox = staleInbox
        self.waitingOn = waitingOn
        self.overdue = overdue
        self.somedayMaybe = somedayMaybe
    }

    /// Converts the report to a JSONValue for MCP responses.
    public func toJSONValue() -> JSONValue {
        .object([
            "unclarified": .array(unclarified.map { $0.toJSONValue() }),
            "staleInbox": .array(staleInbox.map { $0.toJSONValue() }),
            "waitingOn": .array(waitingOn.map { $0.toJSONValue() }),
            "overdue": .array(overdue.map { $0.toJSONValue() }),
            "somedayMaybe": .array(somedayMaybe.map { $0.toJSONValue() })
        ])
    }
}

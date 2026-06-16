import XCTest
@testable import Agenda

final class PlannerTests: XCTestCase {

    // Fixed reference time for deterministic tests: 2026-06-16 12:00 local.
    private let now: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 16
        components.hour = 12
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }()

    private func makeReminder(
        id: String,
        title: String = "Task",
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        priority: Int = 0,
        tags: [String] = [],
        createdDate: Date? = nil
    ) -> Reminder {
        Reminder(
            id: id,
            title: title,
            dueDate: dueDate,
            isCompleted: isCompleted,
            priority: priority,
            listName: "Inbox",
            listId: "list-1",
            tags: tags.map { Tag(name: $0) },
            createdDate: createdDate
        )
    }

    private func daysFromNow(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
    }

    // MARK: - Ranking

    func testRankExcludesCompleted() {
        let reminders = [
            makeReminder(id: "1", isCompleted: true, dueDate: daysFromNow(-1)),
            makeReminder(id: "2", dueDate: daysFromNow(-1))
        ]
        let ranked = Planner.rankNextActions(reminders, now: now)
        XCTAssertEqual(ranked.map { $0.id }, ["2"])
    }

    func testOverdueRanksAboveDueToday() {
        let overdue = makeReminder(id: "overdue", dueDate: daysFromNow(-2))
        let dueToday = makeReminder(id: "today", dueDate: now)
        let ranked = Planner.rankNextActions([dueToday, overdue], now: now)
        XCTAssertEqual(ranked.first?.id, "overdue")
    }

    func testNextActionTagBeatsUntagged() {
        let tagged = makeReminder(id: "tagged", tags: ["next-action"])
        let untagged = makeReminder(id: "untagged")
        let ranked = Planner.rankNextActions([untagged, tagged], now: now)
        XCTAssertEqual(ranked.first?.id, "tagged")
    }

    func testSomedayMaybeIsDeprioritized() {
        let someday = makeReminder(id: "someday", priority: 1, tags: ["someday-maybe"])
        let normal = makeReminder(id: "normal")
        let ranked = Planner.rankNextActions([someday, normal], now: now)
        XCTAssertEqual(ranked.last?.id, "someday")
    }

    func testPriorityBreaksTieAmongUntaggedDatelessTasks() {
        let high = makeReminder(id: "high", priority: 1)
        let low = makeReminder(id: "low", priority: 9)
        let ranked = Planner.rankNextActions([low, high], now: now)
        XCTAssertEqual(ranked.first?.id, "high")
    }

    // MARK: - Day Plan

    func testPlanDayBucketsByFrameworkTags() {
        let reminders = [
            makeReminder(id: "deep", tags: ["deep-work"]),
            makeReminder(id: "quick", tags: ["quick-task"]),
            makeReminder(id: "maint", tags: ["maintenance"]),
            makeReminder(id: "overdue", dueDate: daysFromNow(-1)),
            makeReminder(id: "today", dueDate: now)
        ]
        let plan = Planner.planDay(reminders, now: now)

        XCTAssertEqual(plan.deepWork.map { $0.id }, ["deep"])
        XCTAssertEqual(plan.quickTasks.map { $0.id }, ["quick"])
        XCTAssertEqual(plan.maintenance.map { $0.id }, ["maint"])
        XCTAssertEqual(plan.overdue.map { $0.id }, ["overdue"])
        XCTAssertEqual(plan.dueToday.map { $0.id }, ["today"])
        XCTAssertEqual(plan.focus?.id, "overdue")
    }

    func testPlanDayCapsBucketsAtThree() {
        let reminders = (1...5).map { makeReminder(id: "d\($0)", tags: ["deep-work"]) }
        let plan = Planner.planDay(reminders, now: now)
        XCTAssertEqual(plan.deepWork.count, 3)
    }

    // MARK: - Review

    func testReviewFlagsUnclarifiedAndStaleInbox() {
        let reminders = [
            makeReminder(id: "unclarified"),
            makeReminder(id: "clarified", tags: ["next-action"]),
            makeReminder(id: "stale", tags: ["inbox"], createdDate: daysFromNow(-30)),
            makeReminder(id: "fresh", tags: ["inbox"], createdDate: daysFromNow(-1))
        ]
        let report = Planner.review(reminders, now: now, staleAfterDays: 7)

        XCTAssertTrue(report.unclarified.contains { $0.id == "unclarified" })
        XCTAssertFalse(report.unclarified.contains { $0.id == "clarified" })
        XCTAssertEqual(report.staleInbox.map { $0.id }, ["stale"])
    }

    func testReviewGroupsWaitingAndOverdue() {
        let reminders = [
            makeReminder(id: "waiting", tags: ["waiting-on"]),
            makeReminder(id: "overdue", dueDate: daysFromNow(-3)),
            makeReminder(id: "someday", tags: ["someday-maybe"])
        ]
        let report = Planner.review(reminders, now: now)

        XCTAssertEqual(report.waitingOn.map { $0.id }, ["waiting"])
        XCTAssertEqual(report.overdue.map { $0.id }, ["overdue"])
        XCTAssertEqual(report.somedayMaybe.map { $0.id }, ["someday"])
    }
}

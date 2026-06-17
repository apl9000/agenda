import XCTest
@testable import Agenda

final class TagInferenceTests: XCTestCase {

    private func names(_ tags: [Tag]) -> Set<String> {
        Set(tags.map { $0.name })
    }

    // MARK: - Parsing loose strings

    func testParseGTDStatus() {
        XCTAssertEqual(TagInference.GTDStatus.parse("next action"), .nextAction)
        XCTAssertEqual(TagInference.GTDStatus.parse("#waiting-on"), .waitingOn)
        XCTAssertEqual(TagInference.GTDStatus.parse("Someday Maybe"), .somedayMaybe)
        XCTAssertNil(TagInference.GTDStatus.parse(nil))
        XCTAssertNil(TagInference.GTDStatus.parse("nonsense"))
    }

    func testParseEffort() {
        XCTAssertEqual(TagInference.Effort.parse("deep work"), .deepWork)
        XCTAssertEqual(TagInference.Effort.parse("quick-task"), .quickTask)
        XCTAssertNil(TagInference.Effort.parse(nil))
    }

    // MARK: - Reminder inference

    func testExplicitClassificationWins() {
        let tags = TagInference.inferReminderTags(
            title: "some opaque title",
            notes: nil,
            gtdStatus: .waitingOn,
            effort: .deepWork,
            contexts: ["office"]
        )
        let n = names(tags)
        XCTAssertTrue(n.contains("waiting-on"))
        XCTAssertTrue(n.contains("deep-work"))
        XCTAssertTrue(n.contains("office"))
        XCTAssertFalse(n.contains("next-action"))
    }

    func testFallbackInfersFromContent() {
        let tags = TagInference.inferReminderTags(
            title: "Call dentist about appointment",
            notes: nil,
            gtdStatus: nil,
            effort: nil,
            contexts: []
        )
        let n = names(tags)
        XCTAssertTrue(n.contains("next-action"))   // default GTD status
        XCTAssertTrue(n.contains("quick-task"))    // verb "call"
        XCTAssertTrue(n.contains("calls"))         // context
        XCTAssertTrue(n.contains("health"))        // dentist/appointment
    }

    func testWaitingOnInferredFromNotes() {
        let tags = TagInference.inferReminderTags(
            title: "Send contract",
            notes: "waiting on legal to respond",
            gtdStatus: nil,
            effort: nil,
            contexts: []
        )
        XCTAssertTrue(names(tags).contains("waiting-on"))
        XCTAssertFalse(names(tags).contains("next-action"))
    }

    func testSomedayMaybeInferred() {
        let tags = TagInference.inferReminderTags(
            title: "Maybe learn piano someday",
            notes: nil,
            gtdStatus: nil,
            effort: nil,
            contexts: []
        )
        XCTAssertTrue(names(tags).contains("someday-maybe"))
    }

    func testContextLabelsAreSlugified() {
        let tags = TagInference.inferReminderTags(
            title: "Pick up package",
            notes: nil,
            gtdStatus: .nextAction,
            effort: nil,
            contexts: ["Post Office"]
        )
        XCTAssertTrue(names(tags).contains("post-office"))
    }

    // MARK: - Reminder reconciliation (update)

    func testReconcileReplacesStatusPreservesOthers() {
        let current = [Tag(name: "next-action"), Tag(name: "deep-work"), Tag(name: "home")]
        let result = TagInference.reconcileReminderTags(
            current: current,
            gtdStatus: .waitingOn,
            effort: nil,
            contexts: nil
        )
        let n = names(result)
        XCTAssertTrue(n.contains("waiting-on"))
        XCTAssertTrue(n.contains("deep-work"))   // untouched
        XCTAssertTrue(n.contains("home"))        // untouched
        XCTAssertFalse(n.contains("next-action"))
    }

    func testReconcileContextsReplaceOnlyContexts() {
        let current = [Tag(name: "next-action"), Tag(name: "home"), Tag(name: "errands")]
        let result = TagInference.reconcileReminderTags(
            current: current,
            gtdStatus: nil,
            effort: nil,
            contexts: ["office"]
        )
        let n = names(result)
        XCTAssertTrue(n.contains("next-action")) // gtd preserved
        XCTAssertTrue(n.contains("office"))
        XCTAssertFalse(n.contains("home"))
        XCTAssertFalse(n.contains("errands"))
    }

    func testReconcileEmptyContextsClearsContexts() {
        let current = [Tag(name: "next-action"), Tag(name: "home")]
        let result = TagInference.reconcileReminderTags(
            current: current,
            gtdStatus: nil,
            effort: nil,
            contexts: []
        )
        XCTAssertEqual(names(result), ["next-action"])
    }

    func testReconcileNilLeavesTagsUntouched() {
        let current = [Tag(name: "next-action"), Tag(name: "home")]
        let result = TagInference.reconcileReminderTags(
            current: current,
            gtdStatus: nil,
            effort: nil,
            contexts: nil
        )
        XCTAssertEqual(names(result), names(current))
    }

    // MARK: - Event inference

    func testEventCategoriesFallback() {
        let tags = TagInference.inferEventTags(title: "Team standup", notes: nil, categories: [])
        XCTAssertTrue(names(tags).contains("work"))
    }

    func testEventCategoriesExplicitWins() {
        let tags = TagInference.inferEventTags(title: "Team standup", notes: nil, categories: ["Personal Stuff"])
        let n = names(tags)
        XCTAssertTrue(n.contains("personal-stuff"))
        XCTAssertFalse(n.contains("work")) // no fallback when categories provided
    }
}

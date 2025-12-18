import XCTest
@testable import Agenda

final class TagTests: XCTestCase {

    // MARK: - Tag Creation

    func testTagCreation() {
        let tag = Tag(name: "inbox")
        XCTAssertEqual(tag.name, "inbox")
        XCTAssertEqual(tag.formatted, "#inbox")
    }

    func testTagFromString() {
        let tag1 = Tag.from("#inbox")
        XCTAssertEqual(tag1?.name, "inbox")

        let tag2 = Tag.from("next-action")
        XCTAssertEqual(tag2?.name, "next-action")

        let tag3 = Tag.from("")
        XCTAssertNil(tag3)

        let tag4 = Tag.from("#")
        XCTAssertNil(tag4)
    }

    func testTagNormalization() {
        let tag = Tag(name: "INBOX")
        XCTAssertEqual(tag.name, "inbox")
    }

    // MARK: - GTD Tags

    func testGTDContextTags() {
        XCTAssertTrue(Tag.inbox.isGTDContext)
        XCTAssertTrue(Tag.nextAction.isGTDContext)
        XCTAssertTrue(Tag.waitingOn.isGTDContext)
        XCTAssertTrue(Tag.somedayMaybe.isGTDContext)
        XCTAssertTrue(Tag.reference.isGTDContext)
        XCTAssertTrue(Tag.project.isGTDContext)
    }

    func testNonGTDTag() {
        let tag = Tag(name: "custom")
        XCTAssertFalse(tag.isGTDContext)
    }

    // MARK: - Tag Parsing

    func testExtractTags() {
        let text = "Call dentist #next-action #health"
        let tags = TagParser.extractTags(from: text)

        XCTAssertEqual(tags.count, 2)
        XCTAssertEqual(tags[0].name, "next-action")
        XCTAssertEqual(tags[1].name, "health")
    }

    func testExtractTagsDeduplication() {
        let text = "Test #inbox #INBOX #Inbox"
        let tags = TagParser.extractTags(from: text)

        XCTAssertEqual(tags.count, 1)
        XCTAssertEqual(tags[0].name, "inbox")
    }

    func testExtractTagsNoTags() {
        let text = "No tags here"
        let tags = TagParser.extractTags(from: text)

        XCTAssertTrue(tags.isEmpty)
    }

    func testExtractTagsSpecialCases() {
        // Tags must start with a letter
        let text1 = "#123 #-tag #_underscore"
        let tags1 = TagParser.extractTags(from: text1)
        XCTAssertTrue(tags1.isEmpty)

        // Valid tags with numbers and special chars
        let text2 = "#tag1 #my-tag #my_tag"
        let tags2 = TagParser.extractTags(from: text2)
        XCTAssertEqual(tags2.count, 3)
    }

    // MARK: - Remove Tags

    func testRemoveTags() {
        let text = "Call dentist #next-action tomorrow #health"
        let cleaned = TagParser.removeTags(from: text)

        XCTAssertEqual(cleaned, "Call dentist tomorrow")
    }

    func testRemoveTagsPreservesText() {
        let text = "No tags here"
        let cleaned = TagParser.removeTags(from: text)

        XCTAssertEqual(cleaned, "No tags here")
    }

    // MARK: - Add Tags

    func testAddTags() {
        let text = "Call dentist"
        let result = TagParser.addTags([Tag(name: "inbox")], to: text)

        XCTAssertEqual(result, "Call dentist #inbox")
    }

    func testAddTagsSkipsDuplicates() {
        let text = "Call dentist #inbox"
        let result = TagParser.addTags([Tag(name: "inbox"), Tag(name: "health")], to: text)

        XCTAssertEqual(result, "Call dentist #inbox #health")
    }

    func testAddTagsToEmpty() {
        let result = TagParser.addTags([Tag(name: "inbox")], to: "")

        XCTAssertEqual(result, "#inbox")
    }

    // MARK: - Tag Equality

    func testTagEquality() {
        let tag1 = Tag(name: "inbox")
        let tag2 = Tag(name: "INBOX")
        let tag3 = Tag(name: "other")

        XCTAssertEqual(tag1, tag2)
        XCTAssertNotEqual(tag1, tag3)
    }

    func testTagHashable() {
        var set = Set<Tag>()
        set.insert(Tag(name: "inbox"))
        set.insert(Tag(name: "INBOX"))

        XCTAssertEqual(set.count, 1)
    }
}

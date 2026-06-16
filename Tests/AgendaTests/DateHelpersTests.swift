import XCTest
@testable import Agenda

final class DateHelpersTests: XCTestCase {

    // MARK: - ISO 8601 Parsing

    func testParseISO8601() {
        let dateString = "2024-01-15T09:00:00Z"
        let date = DateHelpers.parse(dateString)

        XCTAssertNotNil(date)
    }

    func testParseISO8601WithFractionalSeconds() {
        let dateString = "2024-01-15T09:00:00.123Z"
        let date = DateHelpers.parse(dateString)

        XCTAssertNotNil(date)
    }

    func testParseDateOnly() {
        let dateString = "2024-01-15"
        let date = DateHelpers.parse(dateString)

        XCTAssertNotNil(date)
    }

    // MARK: - Natural Language Parsing

    func testParseToday() {
        let date = DateHelpers.parseNaturalLanguage("today")

        XCTAssertNotNil(date)
        XCTAssertTrue(date?.isToday ?? false)
    }

    func testParseTomorrow() {
        let date = DateHelpers.parseNaturalLanguage("tomorrow")

        XCTAssertNotNil(date)
        XCTAssertTrue(date?.isTomorrow ?? false)
    }

    func testParseYesterday() {
        let date = DateHelpers.parseNaturalLanguage("yesterday")
        let calendar = Calendar.current

        XCTAssertNotNil(date)
        if let date = date {
            XCTAssertTrue(calendar.isDateInYesterday(date))
        }
    }

    func testParseNextWeek() {
        let date = DateHelpers.parseNaturalLanguage("next week")
        let calendar = Calendar.current

        XCTAssertNotNil(date)
        if let date = date {
            let daysDiff = calendar.dateComponents([.day], from: Date().startOfDay, to: date.startOfDay).day ?? 0
            XCTAssertEqual(daysDiff, 7)
        }
    }

    func testParseRelativeTime() {
        let date = DateHelpers.parseNaturalLanguage("in 2 hours")

        XCTAssertNotNil(date)
        if let date = date {
            let hoursDiff = Calendar.current.dateComponents([.hour], from: Date(), to: date).hour ?? 0
            XCTAssertTrue(hoursDiff >= 1 && hoursDiff <= 2)
        }
    }

    func testParseWeekday() {
        let date = DateHelpers.parseNaturalLanguage("monday")

        XCTAssertNotNil(date)
        if let date = date {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 2) // Monday
        }
    }

    func testParseNextWeekday() {
        let date = DateHelpers.parseNaturalLanguage("next friday")

        XCTAssertNotNil(date)
        if let date = date {
            let weekday = Calendar.current.component(.weekday, from: date)
            XCTAssertEqual(weekday, 6) // Friday
            XCTAssertTrue(date > Date())
        }
    }

    // MARK: - Relative Time Units

    func testParseMinutes() {
        let date = DateHelpers.parseNaturalLanguage("in 30 minutes")
        XCTAssertNotNil(date)
    }

    func testParseDays() {
        let date = DateHelpers.parseNaturalLanguage("in 3 days")

        XCTAssertNotNil(date)
        if let date = date {
            // Round rather than truncate: the parsed date is N days from the
            // moment of parsing, which is a hair before `now` here.
            let daysDiff = Int((date.timeIntervalSinceNow / 86_400).rounded())
            XCTAssertEqual(daysDiff, 3)
        }
    }

    func testParseWeeks() {
        let date = DateHelpers.parseNaturalLanguage("in 2 weeks")

        XCTAssertNotNil(date)
        if let date = date {
            let daysDiff = Int((date.timeIntervalSinceNow / 86_400).rounded())
            XCTAssertEqual(daysDiff, 14)
        }
    }

    // MARK: - Formatting

    func testFormatISO8601() {
        let date = Date()
        let formatted = DateHelpers.formatISO8601(date)

        XCTAssertTrue(formatted.contains("T"))
        XCTAssertTrue(formatted.hasSuffix("Z") || formatted.contains("+") || formatted.contains("-"))
    }

    func testFormatDateOnly() {
        let date = Date()
        let formatted = DateHelpers.formatDateOnly(date)

        // Should be yyyy-MM-dd format
        let components = formatted.split(separator: "-")
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].count, 4) // Year
        XCTAssertEqual(components[1].count, 2) // Month
        XCTAssertEqual(components[2].count, 2) // Day
    }

    func testFormatHumanReadable() {
        let date = Date()
        let formatted = DateHelpers.formatHumanReadable(date)

        XCTAssertFalse(formatted.isEmpty)
    }

    func testFormatRelative() {
        let date = Date().addingTimeInterval(3600) // 1 hour from now
        let formatted = DateHelpers.formatRelative(date)

        XCTAssertFalse(formatted.isEmpty)
        // Should contain "hour" or similar
    }

    // MARK: - Date Extensions

    func testStartOfDay() {
        let date = Date()
        let startOfDay = date.startOfDay

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: startOfDay), 0)
        XCTAssertEqual(calendar.component(.minute, from: startOfDay), 0)
        XCTAssertEqual(calendar.component(.second, from: startOfDay), 0)
    }

    func testEndOfDay() {
        let date = Date()
        let endOfDay = date.endOfDay

        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: endOfDay), 23)
        XCTAssertEqual(calendar.component(.minute, from: endOfDay), 59)
        XCTAssertEqual(calendar.component(.second, from: endOfDay), 59)
    }

    func testIsToday() {
        XCTAssertTrue(Date().isToday)
        XCTAssertFalse(Date().addingTimeInterval(-86400).isToday)
    }

    func testIsTomorrow() {
        let tomorrow = Date().addingTimeInterval(86400)
        XCTAssertTrue(tomorrow.isTomorrow)
        XCTAssertFalse(Date().isTomorrow)
    }

    func testIsPastFuture() {
        let past = Date().addingTimeInterval(-3600)
        let future = Date().addingTimeInterval(3600)

        XCTAssertTrue(past.isPast)
        XCTAssertFalse(past.isFuture)
        XCTAssertTrue(future.isFuture)
        XCTAssertFalse(future.isPast)
    }

    // MARK: - Edge Cases

    func testParseInvalidString() {
        let date = DateHelpers.parse("not a date")
        XCTAssertNil(date)
    }

    func testParseEmptyString() {
        let date = DateHelpers.parse("")
        XCTAssertNil(date)
    }

    func testParseWhitespace() {
        let date = DateHelpers.parse("   tomorrow   ")
        XCTAssertNotNil(date)
    }
}

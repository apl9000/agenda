import Foundation

/// Helpers for parsing and formatting dates in the MCP server.
public enum DateHelpers {
    /// ISO 8601 date formatter with fractional seconds.
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO 8601 date formatter without fractional seconds.
    private static let iso8601FormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Date-only formatter (yyyy-MM-dd).
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    /// Natural language date parser using DataDetector.
    private static let dateDetector: NSDataDetector? = {
        try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    }()

    /// Parses a date string in various formats.
    ///
    /// Supports:
    /// - ISO 8601 with timezone (2024-01-15T09:00:00Z)
    /// - ISO 8601 with fractional seconds (2024-01-15T09:00:00.000Z)
    /// - Date only (2024-01-15)
    /// - Natural language ("tomorrow", "next monday", "in 2 hours")
    ///
    /// - Parameter string: The date string to parse.
    /// - Returns: The parsed date, or nil if parsing fails.
    public static func parse(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try ISO 8601 with fractional seconds
        if let date = iso8601Formatter.date(from: trimmed) {
            return date
        }

        // Try ISO 8601 without fractional seconds
        if let date = iso8601FormatterNoFraction.date(from: trimmed) {
            return date
        }

        // Try date-only format
        if let date = dateOnlyFormatter.date(from: trimmed) {
            return date
        }

        // Try natural language parsing
        if let date = parseNaturalLanguage(trimmed) {
            return date
        }

        return nil
    }

    /// Parses natural language date expressions.
    ///
    /// - Parameter string: The natural language date string.
    /// - Returns: The parsed date, or nil if parsing fails.
    public static func parseNaturalLanguage(_ string: String) -> Date? {
        let lowercased = string.lowercased()
        let now = Date()
        let calendar = Calendar.current

        // Handle common relative terms
        switch lowercased {
        case "today":
            return calendar.startOfDay(for: now)

        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))

        case "yesterday":
            return calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))

        case "next week":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: calendar.startOfDay(for: now))

        case "next month":
            return calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: now))

        default:
            break
        }

        // Handle "in X hours/days/weeks" pattern
        if lowercased.hasPrefix("in ") {
            let remainder = String(lowercased.dropFirst(3))
            if let date = parseRelativeTime(remainder, from: now) {
                return date
            }
        }

        // Handle weekday names
        if let weekday = parseWeekday(lowercased) {
            return nextOccurrence(of: weekday, after: now)
        }

        // Try NSDataDetector for complex expressions
        if let detector = dateDetector {
            let range = NSRange(string.startIndex..., in: string)
            if let match = detector.firstMatch(in: string, options: [], range: range),
               let date = match.date {
                return date
            }
        }

        return nil
    }

    /// Parses relative time expressions like "2 hours", "3 days".
    private static func parseRelativeTime(_ string: String, from date: Date) -> Date? {
        let components = string.split(separator: " ")
        guard components.count >= 2,
              let amount = Int(components[0]) else {
            return nil
        }

        let unit = String(components[1]).lowercased()
        let calendar = Calendar.current

        switch unit {
        case "minute", "minutes", "min", "mins":
            return calendar.date(byAdding: .minute, value: amount, to: date)
        case "hour", "hours", "hr", "hrs":
            return calendar.date(byAdding: .hour, value: amount, to: date)
        case "day", "days":
            return calendar.date(byAdding: .day, value: amount, to: date)
        case "week", "weeks":
            return calendar.date(byAdding: .weekOfYear, value: amount, to: date)
        case "month", "months":
            return calendar.date(byAdding: .month, value: amount, to: date)
        case "year", "years":
            return calendar.date(byAdding: .year, value: amount, to: date)
        default:
            return nil
        }
    }

    /// Parses weekday names.
    private static func parseWeekday(_ string: String) -> Int? {
        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3, "tues": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5, "thurs": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7
        ]

        // Handle "next monday" etc.
        var cleanString = string
        if cleanString.hasPrefix("next ") {
            cleanString = String(cleanString.dropFirst(5))
        }

        return weekdays[cleanString]
    }

    /// Gets the next occurrence of a weekday.
    private static func nextOccurrence(of weekday: Int, after date: Date) -> Date? {
        let calendar = Calendar.current
        let currentWeekday = calendar.component(.weekday, from: date)

        var daysToAdd = weekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: date))
    }

    /// Formats a date as ISO 8601 string.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The ISO 8601 formatted string.
    public static func formatISO8601(_ date: Date) -> String {
        iso8601Formatter.string(from: date)
    }

    /// Formats a date as a date-only string (yyyy-MM-dd).
    ///
    /// - Parameter date: The date to format.
    /// - Returns: The date-only string.
    public static func formatDateOnly(_ date: Date) -> String {
        dateOnlyFormatter.string(from: date)
    }

    /// Formats a date as a human-readable string.
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A human-readable date string.
    public static func formatHumanReadable(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Formats a date relative to now (e.g., "in 2 hours", "tomorrow").
    ///
    /// - Parameter date: The date to format.
    /// - Returns: A relative date string.
    public static func formatRelative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns the start of the day for this date.
    public var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns the end of the day for this date.
    public var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Returns whether this date is today.
    public var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns whether this date is tomorrow.
    public var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }

    /// Returns whether this date is in the past.
    public var isPast: Bool {
        self < Date()
    }

    /// Returns whether this date is in the future.
    public var isFuture: Bool {
        self > Date()
    }
}

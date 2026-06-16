import Foundation

/// Represents a tag extracted from reminder notes.
///
/// Tags are hashtags in the format #tagname that can be used for
/// categorization and GTD workflow integration.
public struct Tag: Hashable, Codable, Sendable {
    /// The tag name without the # prefix.
    public let name: String

    /// Creates a tag with the given name.
    ///
    /// - Parameter name: The tag name (without #).
    public init(name: String) {
        self.name = name.lowercased()
    }

    /// Creates a tag from a string that may include the # prefix.
    ///
    /// - Parameter string: The tag string (with or without #).
    /// - Returns: The tag, or nil if the string is empty.
    public static func from(_ string: String) -> Tag? {
        let trimmed = string.trimmingCharacters(in: .whitespaces)
        let name = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed

        guard !name.isEmpty else { return nil }
        return Tag(name: name)
    }

    /// The tag with the # prefix.
    public var formatted: String {
        "#\(name)"
    }
}

// MARK: - GTD Context Tags

extension Tag {
    /// Inbox tag for uncategorized items.
    public static let inbox = Tag(name: "inbox")

    /// Next action tag for items ready to be done.
    public static let nextAction = Tag(name: "next-action")

    /// Waiting-on tag for items blocked on someone else.
    public static let waitingOn = Tag(name: "waiting-on")

    /// Someday/maybe tag for deferred items.
    public static let somedayMaybe = Tag(name: "someday-maybe")

    /// Reference tag for non-actionable reference material.
    public static let reference = Tag(name: "reference")

    /// Project tag for multi-step outcomes.
    public static let project = Tag(name: "project")

    /// All standard GTD context tags.
    public static let gtdContexts: Set<Tag> = [
        .inbox, .nextAction, .waitingOn, .somedayMaybe, .reference, .project
    ]

    /// Returns whether this is a GTD context tag.
    public var isGTDContext: Bool {
        Self.gtdContexts.contains(self)
    }
}

// MARK: - 3-3-3 Framework Tags

extension Tag {
    /// Deep-work tag for focused, high-energy work (aim for ~3 hours/day).
    public static let deepWork = Tag(name: "deep-work")

    /// Quick-task tag for items that take under ~15 minutes (aim for 3/day).
    public static let quickTask = Tag(name: "quick-task")

    /// Maintenance tag for recurring upkeep that keeps life running (aim for 3/day).
    public static let maintenance = Tag(name: "maintenance")

    /// The 3-3-3 effort tags.
    public static let effortTags: Set<Tag> = [.deepWork, .quickTask, .maintenance]
}

// MARK: - Tag Parsing

/// Utility for parsing tags from text.
public enum TagParser {
    /// Regular expression for matching hashtags.
    ///
    /// The pattern is a compile-time constant and is expected to always compile.
    /// It is stored as an optional (rather than force-unwrapped) so a malformed
    /// pattern can never crash the server — callers degrade gracefully instead.
    private static let tagPattern: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"#([a-zA-Z][a-zA-Z0-9_-]*)"#,
        options: []
    )

    /// Extracts all tags from a string.
    ///
    /// - Parameter text: The text to search for tags.
    /// - Returns: An array of unique tags found in the text.
    public static func extractTags(from text: String) -> [Tag] {
        guard let tagPattern else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        let matches = tagPattern.matches(in: text, options: [], range: range)

        var tags = [Tag]()
        var seenNames = Set<String>()

        for match in matches {
            guard let tagRange = Range(match.range(at: 1), in: text) else { continue }
            let name = String(text[tagRange]).lowercased()

            if !seenNames.contains(name) {
                seenNames.insert(name)
                tags.append(Tag(name: name))
            }
        }

        return tags
    }

    /// Removes all tags from a string, returning the cleaned text.
    ///
    /// - Parameter text: The text to clean.
    /// - Returns: The text with all tags removed and whitespace normalized.
    public static func removeTags(from text: String) -> String {
        guard let tagPattern else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = tagPattern.stringByReplacingMatches(
            in: text,
            options: [],
            range: range,
            withTemplate: ""
        )

        // Normalize whitespace
        return cleaned
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Adds tags to a string if they don't already exist.
    ///
    /// - Parameters:
    ///   - tags: The tags to add.
    ///   - text: The text to add tags to.
    /// - Returns: The text with the tags appended.
    public static func addTags(_ tags: [Tag], to text: String) -> String {
        let existingTags = Set(extractTags(from: text))
        let newTags = tags.filter { !existingTags.contains($0) }

        if newTags.isEmpty {
            return text
        }

        let tagString = newTags.map { $0.formatted }.joined(separator: " ")

        if text.isEmpty {
            return tagString
        }

        return "\(text) \(tagString)"
    }
}

// MARK: - CustomStringConvertible

extension Tag: CustomStringConvertible {
    public var description: String {
        formatted
    }
}

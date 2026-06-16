import Foundation

/// Infers organizational tags for reminders and events from their content.
///
/// Agenda's philosophy is that the *user* should never have to learn or type a
/// tag taxonomy. The connected assistant classifies each item via the structured
/// `gtd_status` / `effort` / `contexts` (and event `categories`) parameters, and
/// this module fills in anything the assistant left blank using lightweight
/// keyword heuristics. The result is a deduplicated set of `Tag`s that get stored
/// (invisibly) as #hashtags in the item's notes.
///
/// All functions here are pure so the classification behavior is unit-testable
/// without EventKit.
public enum TagInference {

    // MARK: - Structured Vocabularies

    /// GTD status a reminder can be classified into.
    public enum GTDStatus: String, CaseIterable, Sendable {
        case inbox
        case nextAction = "next-action"
        case waitingOn = "waiting-on"
        case somedayMaybe = "someday-maybe"
        case project
        case reference

        public var tag: Tag {
            Tag(name: rawValue)
        }

        /// Parses a loosely-formatted status string (e.g. "next action", "#next-action").
        public static func parse(_ raw: String?) -> GTDStatus? {
            guard let raw = raw else { return nil }
            let slug = TagInference.slug(raw)
            return GTDStatus(rawValue: slug)
        }
    }

    /// 3-3-3 effort category a reminder can be classified into.
    public enum Effort: String, CaseIterable, Sendable {
        case deepWork = "deep-work"
        case quickTask = "quick-task"
        case maintenance

        public var tag: Tag {
            Tag(name: rawValue)
        }

        public static func parse(_ raw: String?) -> Effort? {
            guard let raw = raw else { return nil }
            return Effort(rawValue: TagInference.slug(raw))
        }
    }

    // MARK: - Reminder Inference

    /// Builds the full tag set for a new reminder.
    ///
    /// Explicit (assistant-provided) classifications always win; missing ones are
    /// inferred from the title/notes. A reminder always receives a GTD status.
    public static func inferReminderTags(
        title: String,
        notes: String?,
        gtdStatus: GTDStatus?,
        effort: Effort?,
        contexts: [String]
    ) -> [Tag] {
        let haystack = combined(title, notes)
        var tags: [Tag] = []

        // GTD status: explicit wins, else infer. Always present.
        tags.append((gtdStatus ?? inferGTD(haystack)).tag)

        // Effort: explicit wins, else infer (may stay absent).
        if let effort = effort ?? inferEffort(title: title) {
            tags.append(effort.tag)
        }

        // Contexts: explicit wins; only infer when the assistant gave none.
        let contextTags = contexts.isEmpty
            ? inferContexts(haystack).sorted()
            : contexts.map(slug)
        for name in contextTags {
            if let tag = makeTag(name) { tags.append(tag) }
        }

        return dedup(tags)
    }

    /// Reconciles a reminder's existing tags with new explicit classifications.
    ///
    /// Only the categories the assistant actually specified are changed; others
    /// are preserved. No keyword inference happens on update — updates are
    /// deliberate. A `contexts` value of `nil` leaves contexts untouched; an empty
    /// array clears them.
    public static func reconcileReminderTags(
        current: [Tag],
        gtdStatus: GTDStatus?,
        effort: Effort?,
        contexts: [String]?
    ) -> [Tag] {
        var result = current

        if let gtdStatus = gtdStatus {
            result.removeAll { Tag.gtdContexts.contains($0) }
            result.append(gtdStatus.tag)
        }
        if let effort = effort {
            result.removeAll { Tag.effortTags.contains($0) }
            result.append(effort.tag)
        }
        if let contexts = contexts {
            result.removeAll { !Tag.gtdContexts.contains($0) && !Tag.effortTags.contains($0) }
            result.append(contentsOf: contexts.compactMap { makeTag(slug($0)) })
        }

        return dedup(result)
    }

    // MARK: - Event Inference

    /// Builds the category tag set for an event.
    ///
    /// Explicit categories win; only when none are given are categories inferred
    /// from the title/notes.
    public static func inferEventTags(
        title: String,
        notes: String?,
        categories: [String]
    ) -> [Tag] {
        let names = categories.isEmpty
            ? inferEventCategories(combined(title, notes)).sorted()
            : categories.map(slug)
        return dedup(names.compactMap { makeTag($0) })
    }

    /// Reconciles an event's existing category tags with new explicit categories.
    public static func reconcileEventTags(current: [Tag], categories: [String]?) -> [Tag] {
        guard let categories = categories else { return current }
        return dedup(categories.compactMap { makeTag(slug($0)) })
    }

    // MARK: - Keyword Heuristics

    private static func inferGTD(_ haystack: String) -> GTDStatus {
        if containsAny(haystack, ["waiting on", "waiting for", "follow up", "followup", "pending", "blocked on", "heard back"]) {
            return .waitingOn
        }
        if containsAny(haystack, ["someday", "some day", "maybe", "eventually", "one day", "wishlist", "wish list", "would be nice"]) {
            return .somedayMaybe
        }
        // Most captured reminders are concrete actions.
        return .nextAction
    }

    private static func inferEffort(title: String) -> Effort? {
        let verb = firstWord(title)
        let quick: Set<String> = [
            "call", "email", "text", "reply", "respond", "send", "book", "order",
            "pay", "schedule", "confirm", "rsvp", "sign", "ping", "message", "ask", "check"
        ]
        let deep: Set<String> = [
            "write", "design", "plan", "build", "develop", "research", "draft",
            "prepare", "study", "create", "review", "analyze", "outline", "brainstorm", "learn"
        ]
        let maintenance: Set<String> = [
            "clean", "tidy", "organize", "water", "refill", "restock", "renew",
            "backup", "laundry", "dishes", "vacuum", "sort", "file", "declutter", "wash"
        ]
        if quick.contains(verb) { return .quickTask }
        if deep.contains(verb) { return .deepWork }
        if maintenance.contains(verb) { return .maintenance }
        return nil
    }

    private static func inferContexts(_ haystack: String) -> Set<String> {
        var contexts = Set<String>()
        if containsAny(haystack, ["buy", "pick up", "pickup", "drop off", "store", "grocery", "groceries", "shop", "mail", "post office", "pharmacy", "errand"]) {
            contexts.insert("errands")
        }
        if containsAny(haystack, ["call ", "phone", "dial", "voicemail"]) {
            contexts.insert("calls")
        }
        if containsAny(haystack, ["email", "download", "online", "website", "browser", "google", "spreadsheet", "document", "computer"]) {
            contexts.insert("computer")
        }
        if containsAny(haystack, ["home", "house", "kitchen", "garage", "yard", "garden", "apartment"]) {
            contexts.insert("home")
        }
        if containsAny(haystack, ["pay", "bill", "invoice", "bank", "tax", "budget", "rent", "mortgage"]) {
            contexts.insert("finance")
        }
        if containsAny(haystack, ["doctor", "dentist", "appointment", "medication", "prescription", "gym", "workout", "therapy"]) {
            contexts.insert("health")
        }
        return contexts
    }

    private static func inferEventCategories(_ haystack: String) -> Set<String> {
        var categories = Set<String>()
        if containsAny(haystack, ["meeting", "standup", "stand-up", "sync", "1:1", "one on one", "interview", "demo", "presentation", "client", "kickoff", "retro", "planning", "review"]) {
            categories.insert("work")
        }
        if containsAny(haystack, ["doctor", "dentist", "gym", "workout", "therapy", "appointment", "checkup"]) {
            categories.insert("health")
        }
        if containsAny(haystack, ["dinner", "lunch", "coffee", "party", "birthday", "drinks", "date night", "brunch", "wedding"]) {
            categories.insert("social")
        }
        if containsAny(haystack, ["flight", "train", "trip", "hotel", "airport", "travel", "vacation"]) {
            categories.insert("travel")
        }
        return categories
    }

    // MARK: - Helpers

    /// Lowercases, trims, and turns a free-form label into a valid tag slug.
    static func slug(_ raw: String) -> String {
        let trimmed = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let stripped = trimmed.hasPrefix("#") ? String(trimmed.dropFirst()) : trimmed
        var result = ""
        for character in stripped {
            if character.isLetter || character.isNumber {
                result.append(character)
            } else if character == " " || character == "-" || character == "_" {
                result.append("-")
            }
        }
        // Collapse repeated dashes and trim leading/trailing dashes.
        while result.contains("--") {
            result = result.replacingOccurrences(of: "--", with: "-")
        }
        return result.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    /// Builds a Tag from a slug, returning nil if it can't be a valid hashtag.
    private static func makeTag(_ slug: String) -> Tag? {
        // Tags must start with a letter to be re-extractable from notes.
        guard let first = slug.first, first.isLetter else { return nil }
        return Tag(name: slug)
    }

    private static func combined(_ title: String, _ notes: String?) -> String {
        [title, notes ?? ""].joined(separator: " ").lowercased()
    }

    private static func firstWord(_ title: String) -> String {
        let lowered = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return lowered.split(whereSeparator: { $0 == " " || $0 == ":" }).first.map(String.init) ?? lowered
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        needles.contains { haystack.contains($0) }
    }

    private static func dedup(_ tags: [Tag]) -> [Tag] {
        var seen = Set<Tag>()
        var result: [Tag] = []
        for tag in tags where !seen.contains(tag) {
            seen.insert(tag)
            result.append(tag)
        }
        return result
    }
}

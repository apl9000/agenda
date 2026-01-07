import Foundation

/// Defines an MCP tool that can be invoked by clients.
///
/// A tool definition includes metadata about the tool (name, description)
/// and a JSON Schema describing its input parameters.
public struct ToolDefinition: Codable, Sendable {
    /// The unique name of the tool.
    public let name: String

    /// A human-readable description of what the tool does.
    public let description: String

    /// JSON Schema describing the tool's input parameters.
    public let inputSchema: InputSchema

    public init(name: String, description: String, inputSchema: InputSchema) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
    }
}

/// JSON Schema for tool input parameters.
public struct InputSchema: Codable, Sendable {
    /// The type of the schema (always "object" for tool inputs).
    public let type: String

    /// The properties (parameters) of the tool.
    public let properties: [String: PropertySchema]

    /// List of required property names.
    public let required: [String]

    /// Whether additional properties are allowed.
    public let additionalProperties: Bool?

    public init(
        properties: [String: PropertySchema],
        required: [String] = [],
        additionalProperties: Bool? = false
    ) {
        self.type = "object"
        self.properties = properties
        self.required = required
        self.additionalProperties = additionalProperties
    }

    /// Creates an empty schema for tools with no parameters.
    public static var empty: InputSchema {
        InputSchema(properties: [:], required: [])
    }
}

/// JSON Schema for a single property/parameter.
///
/// This is a class to allow recursive schemas (arrays of items, nested objects).
public final class PropertySchema: Codable, Sendable {
    /// The type of the property (string, number, boolean, array, object).
    public let type: String

    /// A description of the property.
    public let description: String?

    /// Allowed values for enum types.
    public let `enum`: [String]?

    /// Default value for the property.
    public let `default`: JSONValue?

    /// For array types, the schema of array items.
    public let items: PropertySchema?

    /// For object types, the nested properties.
    public let properties: [String: PropertySchema]?

    /// For object types, the required nested properties.
    public let required: [String]?

    /// The format of the string (e.g., "date-time", "date", "uri").
    public let format: String?

    public init(
        type: String,
        description: String? = nil,
        `enum`: [String]? = nil,
        `default`: JSONValue? = nil,
        items: PropertySchema? = nil,
        properties: [String: PropertySchema]? = nil,
        required: [String]? = nil,
        format: String? = nil
    ) {
        self.type = type
        self.description = description
        self.enum = `enum`
        self.default = `default`
        self.items = items
        self.properties = properties
        self.required = required
        self.format = format
    }

    // MARK: - Convenience Factory Methods

    /// Creates a string property schema.
    public static func string(description: String? = nil, format: String? = nil) -> PropertySchema {
        PropertySchema(type: "string", description: description, format: format)
    }

    /// Creates an enum property schema.
    public static func `enum`(_ values: [String], description: String? = nil) -> PropertySchema {
        PropertySchema(type: "string", description: description, enum: values)
    }

    /// Creates a boolean property schema.
    public static func boolean(description: String? = nil, default defaultValue: Bool? = nil) -> PropertySchema {
        PropertySchema(
            type: "boolean",
            description: description,
            default: defaultValue.map { .bool($0) }
        )
    }

    /// Creates an integer property schema.
    public static func integer(description: String? = nil, default defaultValue: Int? = nil) -> PropertySchema {
        PropertySchema(
            type: "integer",
            description: description,
            default: defaultValue.map { .int($0) }
        )
    }

    /// Creates a number property schema.
    public static func number(description: String? = nil) -> PropertySchema {
        PropertySchema(type: "number", description: description)
    }

    /// Creates an array property schema.
    public static func array(of items: PropertySchema, description: String? = nil) -> PropertySchema {
        PropertySchema(type: "array", description: description, items: items)
    }

    /// Creates an object property schema.
    public static func object(
        properties: [String: PropertySchema],
        required: [String] = [],
        description: String? = nil
    ) -> PropertySchema {
        PropertySchema(
            type: "object",
            description: description,
            properties: properties,
            required: required
        )
    }
}

/// The result of executing a tool.
public struct ToolResult: Codable, Sendable {
    /// The content items returned by the tool.
    public let content: [ToolContent]

    /// Whether the tool execution resulted in an error.
    public let isError: Bool?

    public init(content: [ToolContent], isError: Bool? = nil) {
        self.content = content
        self.isError = isError
    }

    /// Creates a successful text result.
    public static func text(_ text: String) -> ToolResult {
        ToolResult(content: [.text(text)])
    }

    /// Creates a successful JSON result.
    public static func json(_ value: JSONValue) -> ToolResult {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(value),
           let jsonString = String(data: data, encoding: .utf8) {
            return ToolResult(content: [.text(jsonString)])
        }
        return ToolResult(content: [.text("Error encoding JSON result")])
    }

    /// Creates an error result.
    public static func error(_ message: String) -> ToolResult {
        ToolResult(content: [.text(message)], isError: true)
    }
}

/// Content types that can be returned by a tool.
public enum ToolContent: Codable, Sendable {
    case text(String)

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case text
    }
}

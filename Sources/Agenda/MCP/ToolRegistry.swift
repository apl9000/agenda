import Foundation

/// Protocol for tools that can be executed by the MCP server.
///
/// Implement this protocol to create new tools that can be invoked
/// by MCP clients like Claude Desktop or VS Code.
public protocol MCPTool: Sendable {
    /// The unique name of the tool.
    var name: String { get }

    /// A description of what the tool does.
    var description: String { get }

    /// JSON Schema describing the tool's input parameters.
    var inputSchema: InputSchema { get }

    /// Executes the tool with the given parameters.
    ///
    /// - Parameter params: The parameters passed by the client.
    /// - Returns: The result of the tool execution.
    func execute(params: [String: JSONValue]) async throws -> ToolResult
}

extension MCPTool {
    /// Converts the tool to a ToolDefinition for the tools/list response.
    public var definition: ToolDefinition {
        ToolDefinition(
            name: name,
            description: description,
            inputSchema: inputSchema
        )
    }
}

/// Registry for MCP tools.
///
/// The tool registry manages all available tools and provides
/// methods to register, look up, and execute tools.
public actor ToolRegistry {
    private var tools: [String: any MCPTool] = [:]

    public init() {}

    /// Registers a tool in the registry.
    ///
    /// - Parameter tool: The tool to register.
    /// - Throws: If a tool with the same name is already registered.
    public func register(_ tool: any MCPTool) throws {
        guard tools[tool.name] == nil else {
            throw ToolRegistryError.toolAlreadyExists(tool.name)
        }
        tools[tool.name] = tool
    }

    /// Registers multiple tools at once.
    ///
    /// - Parameter tools: The tools to register.
    /// - Throws: If any tool with the same name is already registered.
    public func register(_ tools: [any MCPTool]) throws {
        for tool in tools {
            try register(tool)
        }
    }

    /// Gets a tool by name.
    ///
    /// - Parameter name: The tool name.
    /// - Returns: The tool if found, nil otherwise.
    public func tool(named name: String) -> (any MCPTool)? {
        tools[name]
    }

    /// Gets all registered tool definitions.
    ///
    /// - Returns: An array of tool definitions.
    public func allDefinitions() -> [ToolDefinition] {
        tools.values.map { $0.definition }.sorted { $0.name < $1.name }
    }

    /// Executes a tool by name with the given parameters.
    ///
    /// - Parameters:
    ///   - name: The tool name.
    ///   - params: The parameters to pass to the tool.
    /// - Returns: The tool result.
    /// - Throws: If the tool is not found or execution fails.
    public func execute(name: String, params: [String: JSONValue]) async throws -> ToolResult {
        guard let tool = tools[name] else {
            throw ToolRegistryError.toolNotFound(name)
        }

        return try await tool.execute(params: params)
    }

    /// Returns the number of registered tools.
    public var count: Int {
        tools.count
    }

    /// Returns true if no tools are registered.
    public var isEmpty: Bool {
        tools.isEmpty
    }
}

/// Errors that can occur in the tool registry.
public enum ToolRegistryError: Error, LocalizedError {
    case toolNotFound(String)
    case toolAlreadyExists(String)

    public var errorDescription: String? {
        switch self {
        case .toolNotFound(let name):
            return "Tool '\(name)' not found in registry"
        case .toolAlreadyExists(let name):
            return "Tool '\(name)' is already registered"
        }
    }
}

// MARK: - Parameter Extraction Helpers
extension Dictionary where Key == String, Value == JSONValue {
    /// Gets a required string parameter.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The string value.
    /// - Throws: If the parameter is missing or not a string.
    public func requireString(_ key: String) throws -> String {
        guard let value = self[key] else {
            throw ParameterError.missing(key)
        }
        guard let stringValue = value.stringValue else {
            throw ParameterError.invalidType(key, expected: "string")
        }
        return stringValue
    }

    /// Gets an optional string parameter.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The string value or nil if not present.
    /// - Throws: If the parameter is present but not a string.
    public func optionalString(_ key: String) throws -> String? {
        guard let value = self[key] else {
            return nil
        }
        if case .null = value {
            return nil
        }
        guard let stringValue = value.stringValue else {
            throw ParameterError.invalidType(key, expected: "string")
        }
        return stringValue
    }

    /// Gets a required boolean parameter.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The boolean value.
    /// - Throws: If the parameter is missing or not a boolean.
    public func requireBool(_ key: String) throws -> Bool {
        guard let value = self[key] else {
            throw ParameterError.missing(key)
        }
        guard let boolValue = value.boolValue else {
            throw ParameterError.invalidType(key, expected: "boolean")
        }
        return boolValue
    }

    /// Gets an optional boolean parameter with a default.
    ///
    /// - Parameters:
    ///   - key: The parameter name.
    ///   - defaultValue: The default value if not present.
    /// - Returns: The boolean value or default.
    /// - Throws: If the parameter is present but not a boolean.
    public func optionalBool(_ key: String, default defaultValue: Bool) throws -> Bool {
        guard let value = self[key] else {
            return defaultValue
        }
        if case .null = value {
            return defaultValue
        }
        guard let boolValue = value.boolValue else {
            throw ParameterError.invalidType(key, expected: "boolean")
        }
        return boolValue
    }

    /// Gets a required integer parameter.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The integer value.
    /// - Throws: If the parameter is missing or not an integer.
    public func requireInt(_ key: String) throws -> Int {
        guard let value = self[key] else {
            throw ParameterError.missing(key)
        }
        guard let intValue = value.intValue else {
            throw ParameterError.invalidType(key, expected: "integer")
        }
        return intValue
    }

    /// Gets an optional integer parameter.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The integer value or nil if not present.
    /// - Throws: If the parameter is present but not an integer.
    public func optionalInt(_ key: String) throws -> Int? {
        guard let value = self[key] else {
            return nil
        }
        if case .null = value {
            return nil
        }
        guard let intValue = value.intValue else {
            throw ParameterError.invalidType(key, expected: "integer")
        }
        return intValue
    }

    /// Gets an optional array of strings.
    ///
    /// - Parameter key: The parameter name.
    /// - Returns: The array of strings or nil if not present.
    /// - Throws: If the parameter is present but not an array of strings.
    public func optionalStringArray(_ key: String) throws -> [String]? {
        guard let value = self[key] else {
            return nil
        }
        if case .null = value {
            return nil
        }
        guard let arrayValue = value.arrayValue else {
            throw ParameterError.invalidType(key, expected: "array")
        }
        return try arrayValue.map { item in
            guard let string = item.stringValue else {
                throw ParameterError.invalidType(key, expected: "array of strings")
            }
            return string
        }
    }
}

/// Errors that can occur when extracting parameters.
public enum ParameterError: Error, LocalizedError {
    case missing(String)
    case invalidType(String, expected: String)
    case invalidValue(String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .missing(let name):
            return "Missing required parameter: '\(name)'"
        case .invalidType(let name, let expected):
            return "Parameter '\(name)' must be of type \(expected)"
        case .invalidValue(let name, let reason):
            return "Invalid value for parameter '\(name)': \(reason)"
        }
    }
}

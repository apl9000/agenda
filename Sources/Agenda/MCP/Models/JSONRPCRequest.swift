import Foundation

/// JSON-RPC 2.0 Request object as defined by the specification.
///
/// A request object represents a method call to the server. It contains
/// the method name, optional parameters, and an identifier to correlate
/// with the response.
public struct JSONRPCRequest: Codable, Sendable {
    /// JSON-RPC protocol version. Must be "2.0".
    public let jsonrpc: String

    /// The name of the method to be invoked.
    public let method: String

    /// The parameters for the method call.
    ///
    /// Can be either a dictionary (named parameters) or an array (positional parameters).
    /// If omitted, the method is called with no parameters.
    public let params: JSONRPCParams?

    /// An identifier established by the client.
    ///
    /// If present, the server must reply with a response containing this same id.
    /// If absent, the request is treated as a notification (no response required).
    public let id: JSONRPCId?

    public init(
        jsonrpc: String = "2.0",
        method: String,
        params: JSONRPCParams? = nil,
        id: JSONRPCId? = nil
    ) {
        self.jsonrpc = jsonrpc
        self.method = method
        self.params = params
        self.id = id
    }

    private enum CodingKeys: String, CodingKey {
        case jsonrpc, method, params, id
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.jsonrpc = try container.decode(String.self, forKey: .jsonrpc)
        self.method = try container.decode(String.self, forKey: .method)
        self.params = try container.decodeIfPresent(JSONRPCParams.self, forKey: .params)

        // Distinguish an explicit null id (a valid id that requires a response)
        // from an absent id (a notification). The synthesized Codable would
        // treat both as nil.
        if container.contains(.id) {
            self.id = try container.decodeIfPresent(JSONRPCId.self, forKey: .id) ?? .null
        } else {
            self.id = nil
        }
    }

    /// Returns true if this is a notification (no id, no response expected).
    public var isNotification: Bool {
        id == nil
    }
}

/// Represents the `id` field in JSON-RPC which can be string, number, or null.
public enum JSONRPCId: Codable, Sendable, Hashable {
    case string(String)
    case number(Int)
    case null

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .number(intValue)
            return
        }

        throw DecodingError.typeMismatch(
            JSONRPCId.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected string, number, or null for JSON-RPC id"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

/// Represents the `params` field in JSON-RPC which can be an object or array.
public enum JSONRPCParams: Codable, Sendable {
    case dictionary([String: JSONValue])
    case array([JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let dict = try? container.decode([String: JSONValue].self) {
            self = .dictionary(dict)
            return
        }

        if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
            return
        }

        throw DecodingError.typeMismatch(
            JSONRPCParams.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Expected object or array for JSON-RPC params"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .dictionary(let dict):
            try container.encode(dict)
        case .array(let arr):
            try container.encode(arr)
        }
    }

    /// Convenience accessor for dictionary parameters.
    public var asDictionary: [String: JSONValue]? {
        if case .dictionary(let dict) = self {
            return dict
        }
        return nil
    }

    /// Convenience accessor for array parameters.
    public var asArray: [JSONValue]? {
        if case .array(let arr) = self {
            return arr
        }
        return nil
    }
}

/// A type-erased JSON value for handling arbitrary JSON structures.
public enum JSONValue: Codable, Sendable, Hashable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
            return
        }

        if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
            return
        }

        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
            return
        }

        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
            return
        }

        if let arrayValue = try? container.decode([JSONValue].self) {
            self = .array(arrayValue)
            return
        }

        if let objectValue = try? container.decode([String: JSONValue].self) {
            self = .object(objectValue)
            return
        }

        throw DecodingError.typeMismatch(
            JSONValue.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unable to decode JSON value"
            )
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .bool(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        }
    }

    /// Convenience accessor for string values.
    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        }
        return nil
    }

    /// Convenience accessor for int values.
    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        }
        return nil
    }

    /// Convenience accessor for bool values.
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        }
        return nil
    }

    /// Convenience accessor for double values.
    public var doubleValue: Double? {
        switch self {
        case .double(let value):
            return value
        case .int(let value):
            return Double(value)
        default:
            return nil
        }
    }

    /// Convenience accessor for array values.
    public var arrayValue: [JSONValue]? {
        if case .array(let value) = self {
            return value
        }
        return nil
    }

    /// Convenience accessor for object values.
    public var objectValue: [String: JSONValue]? {
        if case .object(let value) = self {
            return value
        }
        return nil
    }
}

import Foundation

/// Handles parsing and serializing JSON-RPC 2.0 messages.
///
/// This actor provides thread-safe JSON encoding and decoding for
/// the MCP protocol communication.
public actor JSONRPCHandler {
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    public init() {
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.sortedKeys]
    }

    /// Parses a JSON-RPC request from raw data.
    ///
    /// - Parameter data: The raw JSON data.
    /// - Returns: A parsed request or a parse error.
    public func parseRequest(_ data: Data) -> Result<JSONRPCRequest, JSONRPCResponse> {
        do {
            let request = try decoder.decode(JSONRPCRequest.self, from: data)

            // Validate JSON-RPC version
            guard request.jsonrpc == "2.0" else {
                return .failure(.invalidRequest(id: request.id ?? .null))
            }

            return .success(request)
        } catch {
            return .failure(.parseError())
        }
    }

    /// Parses a JSON-RPC request from a string.
    ///
    /// - Parameter string: The JSON string.
    /// - Returns: A parsed request or a parse error.
    public func parseRequest(_ string: String) -> Result<JSONRPCRequest, JSONRPCResponse> {
        guard let data = string.data(using: .utf8) else {
            return .failure(.parseError())
        }
        return parseRequest(data)
    }

    /// Encodes a JSON-RPC response to a string.
    ///
    /// - Parameter response: The response to encode.
    /// - Returns: The JSON string representation.
    /// - Throws: If encoding fails.
    public func encodeResponse(_ response: JSONRPCResponse) throws -> String {
        let data = try encoder.encode(response)
        guard let string = String(data: data, encoding: .utf8) else {
            throw JSONRPCEncodingError.invalidUTF8
        }
        return string
    }

    /// Encodes any Encodable value to a JSONValue.
    ///
    /// - Parameter value: The value to encode.
    /// - Returns: The JSONValue representation.
    /// - Throws: If encoding fails.
    public func encodeToJSONValue<T: Encodable>(_ value: T) throws -> JSONValue {
        let data = try encoder.encode(value)
        return try decoder.decode(JSONValue.self, from: data)
    }
}

/// Errors that can occur during JSON-RPC encoding.
public enum JSONRPCEncodingError: Error, LocalizedError {
    case invalidUTF8

    public var errorDescription: String? {
        switch self {
        case .invalidUTF8:
            return "Failed to encode response as UTF-8"
        }
    }
}

import Foundation

/// JSON-RPC 2.0 Response object as defined by the specification.
///
/// A response is sent by the server to the client after processing a request.
/// It contains either a result on success or an error on failure.
public struct JSONRPCResponse: Codable, Sendable {
    /// JSON-RPC protocol version. Must be "2.0".
    public let jsonrpc: String

    /// The result of the method call on success.
    ///
    /// This field is mutually exclusive with `error`.
    public let result: JSONValue?

    /// The error object on failure.
    ///
    /// This field is mutually exclusive with `result`.
    public let error: JSONRPCError?

    /// The identifier matching the request this response corresponds to.
    public let id: JSONRPCId

    private init(jsonrpc: String, result: JSONValue?, error: JSONRPCError?, id: JSONRPCId) {
        self.jsonrpc = jsonrpc
        self.result = result
        self.error = error
        self.id = id
    }

    /// Creates a successful response with a result.
    ///
    /// - Parameters:
    ///   - result: The result value to return.
    ///   - id: The request identifier.
    /// - Returns: A new response with the result.
    public static func success(result: JSONValue, id: JSONRPCId) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", result: result, error: nil, id: id)
    }

    /// Creates an error response.
    ///
    /// - Parameters:
    ///   - error: The error object.
    ///   - id: The request identifier.
    /// - Returns: A new response with the error.
    public static func error(_ error: JSONRPCError, id: JSONRPCId) -> JSONRPCResponse {
        JSONRPCResponse(jsonrpc: "2.0", result: nil, error: error, id: id)
    }

    /// Creates a parse error response (used when id cannot be determined).
    ///
    /// - Returns: A new response with parse error and null id.
    public static func parseError() -> JSONRPCResponse {
        JSONRPCResponse(
            jsonrpc: "2.0",
            result: nil,
            error: JSONRPCError.parseError(),
            id: .null
        )
    }

    /// Creates an invalid request error response.
    ///
    /// - Parameter id: The request identifier (if known).
    /// - Returns: A new response with invalid request error.
    public static func invalidRequest(id: JSONRPCId = .null) -> JSONRPCResponse {
        JSONRPCResponse(
            jsonrpc: "2.0",
            result: nil,
            error: JSONRPCError.invalidRequest(),
            id: id
        )
    }
}

/// JSON-RPC 2.0 Error object.
///
/// Contains an error code, message, and optional additional data.
public struct JSONRPCError: Codable, Sendable {
    /// A number indicating the error type.
    public let code: Int

    /// A short description of the error.
    public let message: String

    /// Additional information about the error.
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }

    // MARK: - Standard JSON-RPC Error Codes

    /// Parse error: Invalid JSON was received by the server.
    public static let parseErrorCode = -32700

    /// Invalid Request: The JSON sent is not a valid Request object.
    public static let invalidRequestCode = -32600

    /// Method not found: The method does not exist or is not available.
    public static let methodNotFoundCode = -32601

    /// Invalid params: Invalid method parameter(s).
    public static let invalidParamsCode = -32602

    /// Internal error: Internal JSON-RPC error.
    public static let internalErrorCode = -32603

    // MARK: - Server-defined Error Codes (Reserved: -32000 to -32099)

    /// Permission denied error code.
    public static let permissionDeniedCode = -32000

    /// Resource not found error code.
    public static let resourceNotFoundCode = -32001

    /// Operation failed error code.
    public static let operationFailedCode = -32002

    // MARK: - Factory Methods

    /// Creates a parse error.
    public static func parseError(data: JSONValue? = nil) -> JSONRPCError {
        JSONRPCError(
            code: parseErrorCode,
            message: "Parse error: Invalid JSON was received by the server.",
            data: data
        )
    }

    /// Creates an invalid request error.
    public static func invalidRequest(data: JSONValue? = nil) -> JSONRPCError {
        JSONRPCError(
            code: invalidRequestCode,
            message: "Invalid Request: The JSON sent is not a valid Request object.",
            data: data
        )
    }

    /// Creates a method not found error.
    public static func methodNotFound(_ method: String) -> JSONRPCError {
        JSONRPCError(
            code: methodNotFoundCode,
            message: "Method not found: '\(method)' does not exist or is not available.",
            data: nil
        )
    }

    /// Creates an invalid params error.
    public static func invalidParams(_ message: String) -> JSONRPCError {
        JSONRPCError(
            code: invalidParamsCode,
            message: "Invalid params: \(message)",
            data: nil
        )
    }

    /// Creates an internal error.
    public static func internalError(_ message: String) -> JSONRPCError {
        JSONRPCError(
            code: internalErrorCode,
            message: "Internal error: \(message)",
            data: nil
        )
    }

    /// Creates a permission denied error.
    public static func permissionDenied(_ message: String) -> JSONRPCError {
        JSONRPCError(
            code: permissionDeniedCode,
            message: "Permission denied: \(message)",
            data: nil
        )
    }

    /// Creates a resource not found error.
    public static func resourceNotFound(_ resource: String) -> JSONRPCError {
        JSONRPCError(
            code: resourceNotFoundCode,
            message: "Resource not found: \(resource)",
            data: nil
        )
    }

    /// Creates an operation failed error.
    public static func operationFailed(_ message: String) -> JSONRPCError {
        JSONRPCError(
            code: operationFailedCode,
            message: "Operation failed: \(message)",
            data: nil
        )
    }
}

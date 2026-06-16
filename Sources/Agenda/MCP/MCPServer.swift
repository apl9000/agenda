import Foundation

/// The main MCP server that handles JSON-RPC communication over stdin/stdout.
///
/// The server reads JSON-RPC requests from stdin, processes them, and writes
/// responses to stdout. All logging goes to stderr to avoid interfering with
/// the protocol communication.
public actor MCPServer {
    /// Server information for the initialize response.
    public struct ServerInfo: Codable, Sendable {
        public let name: String
        public let version: String

        public init(name: String, version: String) {
            self.name = name
            self.version = version
        }
    }

    /// MCP protocol version.
    public static let protocolVersion = "2024-11-05"

    /// Server name and version.
    public let serverInfo: ServerInfo

    /// The tool registry.
    private let toolRegistry: ToolRegistry

    /// The JSON-RPC handler.
    private let jsonRPCHandler: JSONRPCHandler

    /// Whether the server has been initialized via the initialize method.
    private var isInitialized = false

    /// Whether the server is running.
    private var isRunning = false

    /// Creates a new MCP server.
    ///
    /// - Parameters:
    ///   - name: The server name.
    ///   - version: The server version.
    ///   - toolRegistry: The tool registry (creates a new one if not provided).
    public init(
        name: String = "Agenda",
        version: String = "0.1.0",
        toolRegistry: ToolRegistry = ToolRegistry()
    ) {
        self.serverInfo = ServerInfo(name: name, version: version)
        self.toolRegistry = toolRegistry
        self.jsonRPCHandler = JSONRPCHandler()
    }

    /// Registers a tool with the server.
    ///
    /// - Parameter tool: The tool to register.
    public func registerTool(_ tool: any MCPTool) async throws {
        try await toolRegistry.register(tool)
    }

    /// Registers multiple tools with the server.
    ///
    /// - Parameter tools: The tools to register.
    public func registerTools(_ tools: [any MCPTool]) async throws {
        try await toolRegistry.register(tools)
    }

    /// Starts the server and begins processing requests.
    ///
    /// This method runs indefinitely until the input stream is closed
    /// or an unrecoverable error occurs.
    public func run() async {
        isRunning = true
        await Logger.shared.info("Starting MCP server: \(serverInfo.name) v\(serverInfo.version)")

        // Read lines from stdin
        while isRunning {
            guard let line = readLine() else {
                await Logger.shared.info("End of input stream, shutting down")
                break
            }

            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                continue
            }

            await Logger.shared.debug("Received: \(trimmed)")

            let response = await handleRequest(trimmed)

            if let response = response {
                await sendResponse(response)
            }
        }

        isRunning = false
        await Logger.shared.info("Server stopped")
    }

    /// Stops the server.
    public func stop() {
        isRunning = false
    }

    /// Handles a single JSON-RPC request.
    ///
    /// - Parameter input: The raw JSON string.
    /// - Returns: A response if one should be sent, nil for notifications.
    private func handleRequest(_ input: String) async -> JSONRPCResponse? {
        // Parse the request
        let parseResult = await jsonRPCHandler.parseRequest(input)

        switch parseResult {
        case .failure(let errorResponse):
            return errorResponse

        case .success(let request):
            // Don't respond to notifications
            guard !request.isNotification else {
                await handleNotification(request)
                return nil
            }

            // Process the request
            return await processRequest(request)
        }
    }

    /// Processes a parsed JSON-RPC request.
    ///
    /// - Parameter request: The parsed request.
    /// - Returns: The response to send.
    private func processRequest(_ request: JSONRPCRequest) async -> JSONRPCResponse {
        guard let id = request.id else {
            return .invalidRequest()
        }

        await Logger.shared.debug("Processing method: \(request.method)")

        do {
            let result = try await routeMethod(request.method, params: request.params)
            return .success(result: result, id: id)
        } catch let error as JSONRPCError {
            return .error(error, id: id)
        } catch let error as PermissionError {
            return .error(error.jsonRPCError, id: id)
        } catch let error as ReminderError {
            return .error(error.jsonRPCError, id: id)
        } catch let error as CalendarError {
            return .error(error.jsonRPCError, id: id)
        } catch let error as ParameterError {
            return .error(.invalidParams(error.localizedDescription), id: id)
        } catch {
            await Logger.shared.error("Unhandled error: \(error)")
            return .error(.internalError(error.localizedDescription), id: id)
        }
    }

    /// Routes a method call to the appropriate handler.
    ///
    /// - Parameters:
    ///   - method: The method name.
    ///   - params: The method parameters.
    /// - Returns: The result as a JSONValue.
    private func routeMethod(_ method: String, params: JSONRPCParams?) async throws -> JSONValue {
        switch method {
        case "initialize":
            return try await handleInitialize(params: params)

        case "initialized":
            // Client notification that initialization is complete
            await Logger.shared.info("Client completed initialization")
            return .object([:])

        case "tools/list":
            return try await handleToolsList()

        case "tools/call":
            return try await handleToolsCall(params: params)

        case "ping":
            return .object([:])

        default:
            throw JSONRPCError.methodNotFound(method)
        }
    }

    /// Handles the initialize method.
    private func handleInitialize(params: JSONRPCParams?) async throws -> JSONValue {
        await Logger.shared.info("Handling initialize request")

        isInitialized = true

        // Build capabilities
        let capabilities: [String: JSONValue] = [
            "tools": .object([:])
        ]

        let result: [String: JSONValue] = [
            "protocolVersion": .string(Self.protocolVersion),
            "capabilities": .object(capabilities),
            "serverInfo": .object([
                "name": .string(serverInfo.name),
                "version": .string(serverInfo.version)
            ])
        ]

        return .object(result)
    }

    /// Handles the tools/list method.
    private func handleToolsList() async throws -> JSONValue {
        let definitions = await toolRegistry.allDefinitions()

        var tools: [JSONValue] = []
        for definition in definitions {
            tools.append(try await jsonRPCHandler.encodeToJSONValue(definition))
        }

        return .object([
            "tools": .array(tools)
        ])
    }

    /// Handles the tools/call method.
    private func handleToolsCall(params: JSONRPCParams?) async throws -> JSONValue {
        guard let dict = params?.asDictionary else {
            throw JSONRPCError.invalidParams("tools/call requires an object with 'name' and 'arguments'")
        }

        guard let nameValue = dict["name"], let toolName = nameValue.stringValue else {
            throw JSONRPCError.invalidParams("Missing required parameter 'name'")
        }

        let arguments: [String: JSONValue]
        if let argsValue = dict["arguments"], let argsDict = argsValue.objectValue {
            arguments = argsDict
        } else {
            arguments = [:]
        }

        await Logger.shared.debug("Calling tool: \(toolName)")

        do {
            let result = try await toolRegistry.execute(name: toolName, params: arguments)
            return try await jsonRPCHandler.encodeToJSONValue(result)
        } catch let error as ToolRegistryError {
            switch error {
            case .toolNotFound(let name):
                throw JSONRPCError.methodNotFound("Tool '\(name)' not found")
            case .toolAlreadyExists:
                throw JSONRPCError.internalError(error.localizedDescription)
            }
        } catch let error as ParameterError {
            throw JSONRPCError.invalidParams(error.localizedDescription)
        }
    }

    /// Handles notification messages (no response expected).
    private func handleNotification(_ request: JSONRPCRequest) async {
        await Logger.shared.debug("Received notification: \(request.method)")

        switch request.method {
        case "notifications/cancelled":
            // Handle request cancellation
            if let params = request.params?.asDictionary,
               let requestId = params["requestId"] {
                await Logger.shared.info("Request cancelled: \(requestId)")
            }

        case "notifications/initialized":
            await Logger.shared.info("Client sent initialized notification")

        default:
            await Logger.shared.warning("Unknown notification: \(request.method)")
        }
    }

    /// Sends a response to stdout.
    private func sendResponse(_ response: JSONRPCResponse) async {
        do {
            let json = try await jsonRPCHandler.encodeResponse(response)
            await Logger.shared.debug("Sending: \(json)")
            print(json)
            fflush(stdout)
        } catch {
            await Logger.shared.error("Failed to encode response: \(error)")
        }
    }
}

import XCTest
@testable import Agenda

/// A mock tool for testing
struct MockTool: MCPTool {
    let name: String
    let description: String
    let inputSchema: InputSchema
    let executeResult: ToolResult

    init(
        name: String = "mock_tool",
        description: String = "A mock tool for testing",
        inputSchema: InputSchema = .empty,
        executeResult: ToolResult = .text("success")
    ) {
        self.name = name
        self.description = description
        self.inputSchema = inputSchema
        self.executeResult = executeResult
    }

    func execute(params: [String: JSONValue]) async throws -> ToolResult {
        executeResult
    }
}

/// A tool that throws errors
struct ErrorTool: MCPTool {
    let name = "error_tool"
    let description = "A tool that throws errors"
    let inputSchema = InputSchema.empty
    let error: Error

    func execute(params: [String: JSONValue]) async throws -> ToolResult {
        throw error
    }
}

final class ToolRegistryTests: XCTestCase {

    // MARK: - Registration

    func testRegisterTool() async throws {
        let registry = ToolRegistry()
        let tool = MockTool()

        try await registry.register(tool)

        let count = await registry.count
        XCTAssertEqual(count, 1)
    }

    func testRegisterMultipleTools() async throws {
        let registry = ToolRegistry()
        let tools = [
            MockTool(name: "tool1"),
            MockTool(name: "tool2"),
            MockTool(name: "tool3")
        ]

        try await registry.register(tools)

        let count = await registry.count
        XCTAssertEqual(count, 3)
    }

    func testRegisterDuplicateToolFails() async {
        let registry = ToolRegistry()
        let tool = MockTool(name: "duplicate")

        do {
            try await registry.register(tool)
            try await registry.register(tool)
            XCTFail("Should have thrown")
        } catch let error as ToolRegistryError {
            if case .toolAlreadyExists(let name) = error {
                XCTAssertEqual(name, "duplicate")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Lookup

    func testLookupExistingTool() async throws {
        let registry = ToolRegistry()
        let tool = MockTool(name: "findme")
        try await registry.register(tool)

        let found = await registry.tool(named: "findme")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.name, "findme")
    }

    func testLookupNonExistentTool() async {
        let registry = ToolRegistry()

        let found = await registry.tool(named: "nonexistent")
        XCTAssertNil(found)
    }

    // MARK: - Definitions

    func testAllDefinitions() async throws {
        let registry = ToolRegistry()
        try await registry.register([
            MockTool(name: "tool_b", description: "B tool"),
            MockTool(name: "tool_a", description: "A tool")
        ])

        let definitions = await registry.allDefinitions()

        XCTAssertEqual(definitions.count, 2)
        // Should be sorted by name
        XCTAssertEqual(definitions[0].name, "tool_a")
        XCTAssertEqual(definitions[1].name, "tool_b")
    }

    // MARK: - Execution

    func testExecuteTool() async throws {
        let registry = ToolRegistry()
        let expectedResult = ToolResult.text("test result")
        let tool = MockTool(name: "exec_test", executeResult: expectedResult)
        try await registry.register(tool)

        let result = try await registry.execute(name: "exec_test", params: [:])

        if case .text(let text) = result.content.first {
            XCTAssertEqual(text, "test result")
        } else {
            XCTFail("Expected text content")
        }
    }

    func testExecuteNonExistentTool() async throws {
        let registry = ToolRegistry()

        do {
            _ = try await registry.execute(name: "nonexistent", params: [:])
            XCTFail("Should have thrown")
        } catch let error as ToolRegistryError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, "nonexistent")
            } else {
                XCTFail("Wrong error type")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Empty State

    func testEmptyRegistry() async {
        let registry = ToolRegistry()

        let isEmpty = await registry.isEmpty
        let count = await registry.count

        XCTAssertTrue(isEmpty)
        XCTAssertEqual(count, 0)
    }

    func testNonEmptyRegistry() async throws {
        let registry = ToolRegistry()
        try await registry.register(MockTool())

        let isEmpty = await registry.isEmpty
        XCTAssertFalse(isEmpty)
    }
}

// MARK: - Parameter Extraction Tests

final class ParameterExtractionTests: XCTestCase {

    func testRequireString() throws {
        let params: [String: JSONValue] = ["name": .string("test")]

        let value = try params.requireString("name")
        XCTAssertEqual(value, "test")
    }

    func testRequireStringMissing() {
        let params: [String: JSONValue] = [:]

        XCTAssertThrowsError(try params.requireString("name")) { error in
            if case ParameterError.missing(let key) = error {
                XCTAssertEqual(key, "name")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testRequireStringWrongType() {
        let params: [String: JSONValue] = ["name": .int(42)]

        XCTAssertThrowsError(try params.requireString("name")) { error in
            if case ParameterError.invalidType(let key, let expected) = error {
                XCTAssertEqual(key, "name")
                XCTAssertEqual(expected, "string")
            } else {
                XCTFail("Wrong error type")
            }
        }
    }

    func testOptionalString() throws {
        let params1: [String: JSONValue] = ["name": .string("test")]
        let params2: [String: JSONValue] = [:]
        let params3: [String: JSONValue] = ["name": .null]

        XCTAssertEqual(try params1.optionalString("name"), "test")
        XCTAssertNil(try params2.optionalString("name"))
        XCTAssertNil(try params3.optionalString("name"))
    }

    func testRequireBool() throws {
        let params: [String: JSONValue] = ["flag": .bool(true)]

        let value = try params.requireBool("flag")
        XCTAssertTrue(value)
    }

    func testOptionalBoolWithDefault() throws {
        let params1: [String: JSONValue] = ["flag": .bool(true)]
        let params2: [String: JSONValue] = [:]

        XCTAssertTrue(try params1.optionalBool("flag", default: false))
        XCTAssertFalse(try params2.optionalBool("flag", default: false))
    }

    func testRequireInt() throws {
        let params: [String: JSONValue] = ["count": .int(42)]

        let value = try params.requireInt("count")
        XCTAssertEqual(value, 42)
    }

    func testOptionalInt() throws {
        let params1: [String: JSONValue] = ["count": .int(42)]
        let params2: [String: JSONValue] = [:]

        XCTAssertEqual(try params1.optionalInt("count"), 42)
        XCTAssertNil(try params2.optionalInt("count"))
    }

    func testOptionalStringArray() throws {
        let params1: [String: JSONValue] = ["tags": .array([.string("a"), .string("b")])]
        let params2: [String: JSONValue] = [:]
        let params3: [String: JSONValue] = ["tags": .null]

        XCTAssertEqual(try params1.optionalStringArray("tags"), ["a", "b"])
        XCTAssertNil(try params2.optionalStringArray("tags"))
        XCTAssertNil(try params3.optionalStringArray("tags"))
    }

    func testOptionalStringArrayWrongItemType() {
        let params: [String: JSONValue] = ["tags": .array([.string("a"), .int(42)])]

        XCTAssertThrowsError(try params.optionalStringArray("tags"))
    }
}

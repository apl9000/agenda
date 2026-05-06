import XCTest
@testable import Agenda

final class JSONRPCTests: XCTestCase {

    // MARK: - JSONValue Tests

    func testJSONValueString() throws {
        let value = JSONValue.string("hello")
        XCTAssertEqual(value.stringValue, "hello")
        XCTAssertNil(value.intValue)
        XCTAssertNil(value.boolValue)
    }

    func testJSONValueInt() throws {
        let value = JSONValue.int(42)
        XCTAssertEqual(value.intValue, 42)
        XCTAssertEqual(value.doubleValue, 42.0)
        XCTAssertNil(value.stringValue)
    }

    func testJSONValueBool() throws {
        let value = JSONValue.bool(true)
        XCTAssertEqual(value.boolValue, true)
        XCTAssertNil(value.stringValue)
    }

    func testJSONValueDouble() throws {
        let value = JSONValue.double(3.14)
        XCTAssertEqual(value.doubleValue, 3.14)
        XCTAssertNil(value.intValue)
    }

    func testJSONValueArray() throws {
        let value = JSONValue.array([.string("a"), .string("b")])
        XCTAssertEqual(value.arrayValue?.count, 2)
        XCTAssertNil(value.objectValue)
    }

    func testJSONValueObject() throws {
        let value = JSONValue.object(["key": .string("value")])
        XCTAssertEqual(value.objectValue?["key"]?.stringValue, "value")
        XCTAssertNil(value.arrayValue)
    }

    // MARK: - JSONRPCId Tests

    func testJSONRPCIdString() throws {
        let json = """
        {"jsonrpc":"2.0","method":"test","id":"abc123"}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        if case .string(let value) = request.id {
            XCTAssertEqual(value, "abc123")
        } else {
            XCTFail("Expected string id")
        }
    }

    func testJSONRPCIdNumber() throws {
        let json = """
        {"jsonrpc":"2.0","method":"test","id":42}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        if case .number(let value) = request.id {
            XCTAssertEqual(value, 42)
        } else {
            XCTFail("Expected number id")
        }
    }

    func testJSONRPCIdNull() throws {
        let json = """
        {"jsonrpc":"2.0","method":"test","id":null}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        if case .null = request.id {
            // Success
        } else {
            XCTFail("Expected null id")
        }
    }

    // MARK: - JSONRPCRequest Tests

    func testParseValidRequest() throws {
        let json = """
        {"jsonrpc":"2.0","method":"tools/list","id":1}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertEqual(request.jsonrpc, "2.0")
        XCTAssertEqual(request.method, "tools/list")
        XCTAssertFalse(request.isNotification)
    }

    func testParseRequestWithParams() throws {
        let json = """
        {"jsonrpc":"2.0","method":"tools/call","params":{"name":"test","arguments":{}},"id":1}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertNotNil(request.params)
        if let dict = request.params?.asDictionary {
            XCTAssertEqual(dict["name"]?.stringValue, "test")
        } else {
            XCTFail("Expected dictionary params")
        }
    }

    func testParseNotification() throws {
        let json = """
        {"jsonrpc":"2.0","method":"notifications/cancelled"}
        """
        let data = json.data(using: .utf8)!
        let request = try JSONDecoder().decode(JSONRPCRequest.self, from: data)

        XCTAssertTrue(request.isNotification)
        XCTAssertNil(request.id)
    }

    // MARK: - JSONRPCResponse Tests

    func testSuccessResponse() throws {
        let response = JSONRPCResponse.success(
            result: .object(["status": .string("ok")]),
            id: .number(1)
        )

        XCTAssertEqual(response.jsonrpc, "2.0")
        XCTAssertNotNil(response.result)
        XCTAssertNil(response.error)
    }

    func testErrorResponse() throws {
        let response = JSONRPCResponse.error(
            .methodNotFound("unknown"),
            id: .number(1)
        )

        XCTAssertNil(response.result)
        XCTAssertNotNil(response.error)
        XCTAssertEqual(response.error?.code, JSONRPCError.methodNotFoundCode)
    }

    func testParseErrorResponse() throws {
        let response = JSONRPCResponse.parseError()

        XCTAssertEqual(response.error?.code, JSONRPCError.parseErrorCode)
        if case .null = response.id {
            // Expected
        } else {
            XCTFail("Expected null id for parse error")
        }
    }

    // MARK: - JSONRPCError Tests

    func testStandardErrorCodes() {
        XCTAssertEqual(JSONRPCError.parseErrorCode, -32700)
        XCTAssertEqual(JSONRPCError.invalidRequestCode, -32600)
        XCTAssertEqual(JSONRPCError.methodNotFoundCode, -32601)
        XCTAssertEqual(JSONRPCError.invalidParamsCode, -32602)
        XCTAssertEqual(JSONRPCError.internalErrorCode, -32603)
    }

    func testCustomErrorCodes() {
        XCTAssertEqual(JSONRPCError.permissionDeniedCode, -32000)
        XCTAssertEqual(JSONRPCError.resourceNotFoundCode, -32001)
        XCTAssertEqual(JSONRPCError.operationFailedCode, -32002)
    }
}

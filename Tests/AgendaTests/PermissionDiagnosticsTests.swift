import EventKit
import XCTest
@testable import Agenda

/// Status mapping and diagnostic JSON. These tests use synthetic reports and
/// `EKAuthorizationStatus` case values only. They do not create an event store,
/// request access, or read calendar or reminder data.
final class PermissionDiagnosticsTests: XCTestCase {

    // MARK: - Status mapping

    func testMapsEachNamedAuthorizationStatus() throws {
        XCTAssertEqual(AuthorizationStatusName(eventKit: .notDetermined), .notDetermined)
        XCTAssertEqual(AuthorizationStatusName(eventKit: .restricted), .restricted)
        XCTAssertEqual(AuthorizationStatusName(eventKit: .denied), .denied)
        XCTAssertEqual(AuthorizationStatusName(eventKit: .fullAccess), .fullAccess)
        XCTAssertEqual(AuthorizationStatusName(eventKit: .writeOnly), .writeOnly)

        // EKAuthorizationStatusAuthorized is raw value 3 in EKTypes.h. Naming
        // the deprecated case warns on the macOS 14 SDK, so this uses the raw
        // value. When fullAccess has that same value, the mapper reports fullAccess.
        let legacy = try XCTUnwrap(EKAuthorizationStatus(rawValue: 3))
        let mapped = AuthorizationStatusName(eventKit: legacy)
        if EKAuthorizationStatus.fullAccess.rawValue == 3 {
            XCTAssertEqual(mapped, .fullAccess)
        } else {
            XCTAssertEqual(mapped, .authorized)
        }
    }

    func testNamedStatusesStayDistinctFromDenied() {
        let distinct: [AuthorizationStatusName] = [
            AuthorizationStatusName(eventKit: .notDetermined),
            AuthorizationStatusName(eventKit: .restricted),
            AuthorizationStatusName(eventKit: .denied),
            AuthorizationStatusName(eventKit: .fullAccess),
            AuthorizationStatusName(eventKit: .writeOnly)
        ]
        XCTAssertEqual(Set(distinct.map(\.rawValue)).count, distinct.count)
        XCTAssertNotEqual(AuthorizationStatusName(eventKit: .notDetermined), .denied)
        XCTAssertNotEqual(AuthorizationStatusName(eventKit: .restricted), .denied)
        XCTAssertNotEqual(AuthorizationStatusName(eventKit: .writeOnly), .denied)
    }

    func testStableRawValuesForOriginalStatuses() {
        XCTAssertEqual(EKAuthorizationStatus.notDetermined.rawValue, 0)
        XCTAssertEqual(EKAuthorizationStatus.restricted.rawValue, 1)
        XCTAssertEqual(EKAuthorizationStatus.denied.rawValue, 2)
    }

    func testFullAccessRequestIsAttemptedOnlyWhenNotDetermined() {
        var cases: [(EKAuthorizationStatus, Bool)] = [
            (.notDetermined, true),
            (.restricted, false),
            (.denied, false),
            (.fullAccess, false),
            (.writeOnly, false)
        ]
        if let legacy = EKAuthorizationStatus(rawValue: 3), legacy != .fullAccess {
            cases.append((legacy, false))
        }
        for (status, expected) in cases {
            let name = AuthorizationStatusName(eventKit: status)
            XCTAssertEqual(
                AuthorizationStatusName.shouldAttemptFullAccessRequest(name),
                expected,
                "raw \(status.rawValue) mapped to \(name.rawValue)"
            )
        }
    }

    func testRemindersAndCalendarGrantRulesMatchTheRequestMethods() {
        XCTAssertTrue(AuthorizationStatusName.fullAccess.allowsRemindersUse)
        XCTAssertTrue(AuthorizationStatusName.authorized.allowsRemindersUse)
        XCTAssertTrue(AuthorizationStatusName.writeOnly.allowsRemindersUse)
        XCTAssertFalse(AuthorizationStatusName.notDetermined.allowsRemindersUse)
        XCTAssertFalse(AuthorizationStatusName.restricted.allowsRemindersUse)
        XCTAssertFalse(AuthorizationStatusName.denied.allowsRemindersUse)
        XCTAssertFalse(AuthorizationStatusName.unknown.allowsRemindersUse)

        XCTAssertTrue(AuthorizationStatusName.fullAccess.allowsCalendarUse)
        XCTAssertTrue(AuthorizationStatusName.authorized.allowsCalendarUse)
        XCTAssertFalse(AuthorizationStatusName.writeOnly.allowsCalendarUse)
        XCTAssertFalse(AuthorizationStatusName.notDetermined.allowsCalendarUse)
        XCTAssertFalse(AuthorizationStatusName.restricted.allowsCalendarUse)
        XCTAssertFalse(AuthorizationStatusName.denied.allowsCalendarUse)
        XCTAssertFalse(AuthorizationStatusName.unknown.allowsCalendarUse)
    }

    // MARK: - Diagnostic JSON

    func testNotDeterminedRequestFailureIsNotRelabeledDenied() throws {
        let diagnostic = PermissionDiagnostic(
            reminders: .afterReturn(granted: false, status: .notDetermined, rawValue: 0),
            calendar: .afterFailure(
                error: PermissionRequestError(
                    domain: "EKCADErrorDomain",
                    code: 1013,
                    description: "synthetic failure"
                ),
                status: .notDetermined,
                rawValue: 0
            )
        )

        XCTAssertFalse(diagnostic.allGranted)
        let object = try jsonValue(diagnostic)

        let reminders = try entity(object, named: "reminders")
        XCTAssertEqual(reminders["status"], .string("notDetermined"))
        XCTAssertEqual(reminders["statusRawValue"], .int(0))
        XCTAssertEqual(reminders["requestAttempted"], .bool(true))
        XCTAssertEqual(reminders["requestGranted"], .bool(false))
        XCTAssertEqual(reminders["requestError"], .null)

        let calendar = try entity(object, named: "calendar")
        XCTAssertEqual(calendar["status"], .string("notDetermined"))
        XCTAssertEqual(calendar["requestAttempted"], .bool(true))
        XCTAssertEqual(calendar["requestGranted"], .null)
        let error = try entityValue(calendar["requestError"])
        XCTAssertEqual(error["domain"], .string("EKCADErrorDomain"))
        XCTAssertEqual(error["code"], .int(1013))
        XCTAssertEqual(error["description"], .string("synthetic failure"))

        let text = try jsonText(from: diagnostic)
        XCTAssertFalse(text.contains("\"denied\""))
        XCTAssertFalse(text.contains("\"granted\""))
    }

    func testDeniedAndRestrictedAreNotRequests() throws {
        let denied = EntityPermissionReport.notAttempted(status: .denied, rawValue: 2)
        let restricted = EntityPermissionReport.notAttempted(status: .restricted, rawValue: 1)

        let deniedJSON = try jsonValue(denied)
        XCTAssertEqual(deniedJSON["status"], .string("denied"))
        XCTAssertEqual(deniedJSON["requestAttempted"], .bool(false))
        XCTAssertEqual(deniedJSON["requestGranted"], .null)
        XCTAssertEqual(deniedJSON["requestError"], .null)

        let restrictedJSON = try jsonValue(restricted)
        XCTAssertEqual(restrictedJSON["status"], .string("restricted"))
        XCTAssertEqual(restrictedJSON["requestAttempted"], .bool(false))
        XCTAssertNotEqual(restrictedJSON["status"], .string("denied"))
    }

    func testWriteOnlyCalendarDoesNotCountAsFullAccess() {
        let diagnostic = PermissionDiagnostic(
            reminders: .notAttempted(status: .writeOnly, rawValue: 4),
            calendar: .notAttempted(status: .writeOnly, rawValue: 4)
        )
        XCTAssertTrue(diagnostic.reminders.status.allowsRemindersUse)
        XCTAssertFalse(diagnostic.calendar.status.allowsCalendarUse)
        XCTAssertFalse(diagnostic.allGranted)
        XCTAssertFalse(diagnostic.reminders.requestAttempted)
        XCTAssertFalse(diagnostic.calendar.requestAttempted)
    }

    func testAllGrantedOmitsHelp() throws {
        let diagnostic = PermissionDiagnostic(
            reminders: .notAttempted(status: .fullAccess, rawValue: 3),
            calendar: .notAttempted(status: .authorized, rawValue: 3)
        )
        XCTAssertTrue(diagnostic.allGranted)
        XCTAssertNil(diagnostic.help)
        let object = try jsonValue(diagnostic)
        XCTAssertEqual(object["allGranted"], .bool(true))
        XCTAssertEqual(object["help"], .null)
    }

    func testHelpQuotesTheReportedStatusAndSettingsPaths() throws {
        let diagnostic = PermissionDiagnostic(
            reminders: .notAttempted(status: .denied, rawValue: 2),
            calendar: .afterReturn(granted: false, status: .notDetermined, rawValue: 0)
        )
        let help = try XCTUnwrap(diagnostic.help)
        XCTAssertTrue(help.contains("Reminders status is denied."))
        XCTAssertTrue(help.contains("No full-access request was attempted."))
        XCTAssertTrue(help.contains("Calendar status is notDetermined."))
        XCTAssertTrue(help.contains("returned false"))
        XCTAssertTrue(help.contains("System Settings → Privacy & Security → Calendars"))
        XCTAssertTrue(help.contains("System Settings → Privacy & Security → Reminders"))
        XCTAssertFalse(help.contains("Calendar status is denied"))
    }

    func testRequestErrorDropsUserInfoBeyondDomainCodeAndDescription() throws {
        let error = NSError(
            domain: "TestDomain",
            code: 42,
            userInfo: [
                NSLocalizedDescriptionKey: "synthetic failure",
                "calendarTitle": "Dentist appointment"
            ]
        )
        let info = PermissionRequestError(error)
        XCTAssertEqual(info.domain, "TestDomain")
        XCTAssertEqual(info.code, 42)
        XCTAssertEqual(info.description, "synthetic failure")

        let data = try JSONEncoder().encode(info)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("Dentist"))
        XCTAssertFalse(text.contains("calendarTitle"))
    }

    func testDebugResponseLogRedactsRequestErrorDescription() async throws {
        let diagnostic = PermissionDiagnostic(
            reminders: .afterFailure(
                error: PermissionRequestError(
                    domain: "EKCADErrorDomain",
                    code: 1013,
                    description: "Dentist appointment"
                ),
                status: .notDetermined,
                rawValue: 0
            ),
            calendar: .notAttempted(status: .notDetermined, rawValue: 0)
        )
        let handler = JSONRPCHandler()
        let toolResult = try await handler.encodeToJSONValue(ToolResult.json(try diagnostic.toJSONValue()))
        let response = JSONRPCResponse.success(result: toolResult, id: .number(1))
        let clientJSON = try await handler.encodeResponse(response)
        let logged = PermissionDiagnosticsLogging.redactRequestErrorDescriptions(in: clientJSON)

        XCTAssertTrue(clientJSON.contains("Dentist appointment"))
        XCTAssertFalse(logged.contains("Dentist"))
        XCTAssertFalse(logged.contains("appointment"))
        XCTAssertTrue(logged.contains(PermissionDiagnosticsLogging.redactedDescription))
        XCTAssertTrue(logged.contains("EKCADErrorDomain"))
        XCTAssertTrue(logged.contains("1013"))
    }

    func testStderrLineContainsDomainAndCodeOnly() {
        let error = PermissionRequestError(
            domain: "EKCADErrorDomain",
            code: 1013,
            description: "Dentist appointment"
        )
        let line = PermissionDiagnosticsLogging.requestFailedLine(entity: "Reminders", error: error)
        XCTAssertEqual(line, "Reminders full-access request failed: EKCADErrorDomain 1013")
        XCTAssertFalse(line.contains("Dentist"))
        XCTAssertFalse(line.contains("appointment"))
    }

    // MARK: - CLI parsing

    func testCheckPermissionsFlagDoesNotStartTheServer() {
        XCTAssertEqual(
            Agenda.command(from: ["agenda", "--check-permissions"]),
            .checkPermissions(debug: false)
        )
        XCTAssertEqual(
            Agenda.command(from: ["agenda", "--debug", "--check-permissions"]),
            .checkPermissions(debug: true)
        )
        XCTAssertEqual(Agenda.command(from: ["agenda"]), .serve(debug: false))
        XCTAssertEqual(Agenda.command(from: ["agenda", "--debug"]), .serve(debug: true))
        XCTAssertEqual(Agenda.command(from: ["agenda", "--help", "--check-permissions"]), .help)
        XCTAssertEqual(Agenda.command(from: ["agenda", "--version"]), .version)
    }

    // MARK: - Source plist

    func testSourceInfoPlistDeclaresRequiredUsageKeys() throws {
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/Agenda/Info.plist")
        let data = try Data(contentsOf: plistURL)
        let raw = try PropertyListSerialization.propertyList(from: data, format: nil)
        let plist = try XCTUnwrap(raw as? [String: Any])

        XCTAssertEqual(plist["CFBundleIdentifier"] as? String, "cloud.rives.agenda")
        XCTAssertEqual(plist["CFBundleName"] as? String, "Agenda")
        XCTAssertEqual(plist["CFBundleShortVersionString"] as? String, Agenda.version)

        let required = [
            "NSCalendarsFullAccessUsageDescription",
            "NSRemindersFullAccessUsageDescription",
            "NSCalendarsUsageDescription",
            "NSRemindersUsageDescription"
        ]
        for key in required {
            let value = try XCTUnwrap(plist[key] as? String, "missing \(key)")
            XCTAssertFalse(value.isEmpty, "empty \(key)")
        }
    }

    // MARK: - Helpers

    /// JSON object whose missing keys read as null, so assertions compare `JSONValue` to `JSONValue`.
    private struct JSONObject {
        let fields: [String: JSONValue]

        subscript(key: String) -> JSONValue {
            fields[key] ?? .null
        }
    }

    private func jsonValue(_ value: some Encodable) throws -> JSONObject {
        let data: Data
        if let diagnostic = value as? PermissionDiagnostic {
            data = try diagnostic.jsonData()
        } else {
            data = try JSONEncoder().encode(value)
        }
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object(let object) = decoded else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "expected a JSON object")
            )
        }
        return JSONObject(fields: object)
    }

    private func jsonText(from diagnostic: PermissionDiagnostic) throws -> String {
        let data = try diagnostic.jsonData()
        return String(decoding: data, as: UTF8.self)
    }

    private func entity(_ object: JSONObject, named key: String) throws -> JSONObject {
        guard case .object(let nested) = object[key] else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "expected an object at \(key)")
            )
        }
        return JSONObject(fields: nested)
    }

    private func entityValue(_ value: JSONValue) throws -> JSONObject {
        guard case .object(let nested) = value else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "expected an object")
            )
        }
        return JSONObject(fields: nested)
    }
}

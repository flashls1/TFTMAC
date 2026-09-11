import Foundation
import XCTest

final class DiagnosticArtifactFileTests: XCTestCase {
    func testStartupFailureReceiptIsPrivateReadableAndRetainedAcrossFailures() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try DiagnosticArtifactFile.persistStartupFailure("specific AVD failure", applicationSupport: root)
        let second = try DiagnosticArtifactFile.persistStartupFailure("later failure", applicationSupport: root)
        XCTAssertNotEqual(first, second)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: first)) as? [String: Any])
        XCTAssertEqual(object["error"] as? String, "specific AVD failure")
        let attributes = try FileManager.default.attributesOfItem(atPath: first.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        let blocked = root.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: blocked)
        XCTAssertThrowsError(try DiagnosticArtifactFile.persistStartupFailure("failure", applicationSupport: blocked))
    }

    private enum InjectedFailure: Error { case parser, diskWrite }
    private let validSummary = Data("trace_start_ns,trace_end_ns,process_rows,thread_rows,scheduler_slices,counter_rows,surfaceflinger_slices,tft_process_rows\n1,1000,4,8,20,3,9,1\n".utf8)

    private func withRaw(_ body: (DiagnosticArtifactFile.Seal) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("capture.pftrace")
        try Data([1, 2, 3, 4]).write(to: url)
        try body(DiagnosticArtifactFile.seal(url))
    }

    func testParserFailurePreservesPrivateRawIdentity() throws {
        try withRaw { raw in
            XCTAssertThrowsError(try DiagnosticArtifactFile.normalize(raw, parser: { _ in throw InjectedFailure.parser }))
            try DiagnosticArtifactFile.verify(raw)
            let permissions = try FileManager.default.attributesOfItem(atPath: raw.url.path)[.posixPermissions] as? NSNumber
            XCTAssertEqual(permissions?.intValue, 0o600)
        }
    }

    func testFailedArtifactWritePreservesRawAndDoesNotProduceSummary() throws {
        try withRaw { raw in
            XCTAssertThrowsError(try DiagnosticArtifactFile.normalize(raw, parser: { _ in self.validSummary },
                writer: { _, _ in throw InjectedFailure.diskWrite }))
            try DiagnosticArtifactFile.verify(raw)
            XCTAssertFalse(FileManager.default.fileExists(atPath: raw.url.appendingPathExtension("normalized.csv").path))
        }
    }

    func testNonemptyParserErrorCannotPassAsNormalizedEvidence() throws {
        try withRaw { raw in
            for summary in [Data("Error: parser unavailable\n".utf8), validSummary + validSummary,
                            Data("trace_start_ns,trace_end_ns\n1,2\n".utf8)] {
                XCTAssertThrowsError(try DiagnosticArtifactFile.normalize(raw, parser: { _ in summary })) { error in
                    XCTAssertEqual(error as? DiagnosticArtifactFile.Failure, .malformedSummary)
                }
            }
            try DiagnosticArtifactFile.verify(raw)
        }
    }

    func testRawMutationRejectsAnalysisBeforeParserRuns() throws {
        try withRaw { raw in
            try Data([9, 9, 9, 9]).write(to: raw.url)
            XCTAssertThrowsError(try DiagnosticArtifactFile.normalize(raw, parser: { _ in
                XCTFail("Changed raw data must be rejected before parsing")
                return self.validSummary
            })) { error in
                XCTAssertEqual(error as? DiagnosticArtifactFile.Failure, .rawIdentityChanged)
            }
        }
    }

    func testValidNormalizationSealsSummaryAndKeepsRaw() throws {
        try withRaw { raw in
            let result = try DiagnosticArtifactFile.normalize(raw, parser: { _ in self.validSummary })
            XCTAssertEqual(try Data(contentsOf: result.url), validSummary)
            XCTAssertEqual(result.sha256.count, 64)
            try DiagnosticArtifactFile.verify(raw)
        }
    }
    private func viewEvidence(_ lines: String, pid: Int32 = 42) throws -> ANGLEViewEvidence.Summary {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        try Data(lines.utf8).write(to: file)
        return try ANGLEViewEvidence.normalize(files: [file], pid: pid) { event in
            XCTAssertEqual(event.pid, pid)
            if event.kind == "CREATE_BUFFER_VIEW" {
                XCTAssertEqual(event.durationNS, 10)
                XCTAssertEqual(event.values["range"], UInt64.max)
            }
        }
    }

    func testDriverRecordsPreserveRequestAndSwapIdentityAcrossLogcatOverlap() throws {
        let frame = "09-06 03:00:00.000 42 43 I TFTMAC_VIEW: F 1 13 1 100 1 1 2 3 1 10 4 1 2 3 4 5 1 0\n"
        let span = "09-06 03:00:00.000 42 43 I TFTMAC_VIEW: S 1 13 1 0 1,90,10,100,0,18446744073709551615;\n"
        let result = try viewEvidence(frame + span + frame + span)
        XCTAssertTrue(result.healthy)
        XCTAssertEqual(result.frames, 1)
        XCTAssertEqual(result.spans, 1)
        XCTAssertEqual(result.duplicates, 2)
    }

    func testMissingDriverProducerLostRecordAndMalformedPayloadCannotPassCoverage() throws {
        let frame = "09-06 03:00:00.000 42 43 I TFTMAC_VIEW: F 1 13 1 100 1 0 0 0 0 0 0 0 0 0 0 0 0 0\n"
        XCTAssertFalse(try viewEvidence(frame, pid: 99).healthy)
        let gap = try viewEvidence(frame + frame.replacingOccurrences(of: "13 1 100", with: "13 3 120"))
        XCTAssertFalse(gap.healthy)
        XCTAssertEqual(gap.missingFrames, 1)
        XCTAssertFalse(try viewEvidence(frame.replacingOccurrences(of: "F 1 13", with: "F 2 13")).healthy)
        let missing = "09-06 03:00:00.000 42 43 I TFTMAC_VIEW: F 1 13 1 100 1 0 0 0 1 10 0 0 0 0 0 0 1 0\n"
        XCTAssertEqual(try viewEvidence(missing).missingSpans, 1)
        XCTAssertFalse(try viewEvidence(missing).healthy)
    }

}

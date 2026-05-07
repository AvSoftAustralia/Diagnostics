//
//  LogsTrimmerTests.swift
//  
//
//  Created by Antoine van der Lee on 01/03/2024.
//
//  swiftlint:disable line_length

@testable import Diagnostics
import XCTest

final class LogsTrimmerTests: XCTestCase {

    /// It should trim the oldest line and skip session headers.
    func testTrimmingSessionsSingleLine() {
        let lineToTrim = """
        <p class="system"><span class="log-date">2024-02-20 10:33:47</span><span class="log-separator"> | </span><span class="log-message">SYSTEM: 2024-02-20 10:33:47.086 Collect[32949:1669571] Reachability Flag Status: -R t------ reachabilityStatusForFlags</span></p>
        """
        
        let input = """
        <summary><div class="session-header"><p><span>Date: </span>2024-02-20 10:33:47</p><p><span>System: </span>iOS 16.3</p><p><span>Locale: </span>en-GB</p><p><span>Version: </span>6.2.8 (17000)</p></div></summary>
        \(lineToTrim)
        <p class="system"><span class="log-date">2024-02-20 10:33:47</span><span class="log-separator"> | </span><span class="log-message">SYSTEM: 2024-02-20 10:33:47.101 Collect[32949:1669571] [Firebase/Crashlytics] Version 8.15.0</span></p>
        """

        let expectedOutput = input.replacingOccurrences(of: lineToTrim, with: "")
        
        var inputData = Data(input.utf8)
        let targetSize = Data(expectedOutput.utf8).count
        let trimmer = LogsTrimmer()

        XCTAssertTrue(trimmer.trim(data: &inputData, maximumSize: targetSize, targetSize: targetSize))

        let outputString = String(data: inputData, encoding: .utf8)
        XCTAssertEqual(outputString, expectedOutput)
    }

    /// It should trim the oldest lines and skip session headers.
    func testTrimmingSessionsMultipleLines() {
        let expectedOutput = """
        <summary><div class="session-header"><p><span>Date: </span>2024-02-20 10:33:47</p><p><span>System: </span>iOS 16.3</p><p><span>Locale: </span>en-GB</p><p><span>Version: </span>6.2.8 (17000)</p></div></summary>
        """

        var input = expectedOutput
        input += """
        <p class="system"><span class="log-date">2024-02-20 10:33:47</span><span class="log-separator"> | </span><span class="log-message">SYSTEM: 2024-02-20 10:33:47.086 Collect[32949:1669571] Reachability Flag Status: -R t------ reachabilityStatusForFlags</span></p>
        <p class="system"><span class="log-date">2024-02-20 10:33:47</span><span class="log-separator"> | </span><span class="log-message">SYSTEM: 2024-02-20 10:33:47.101 Collect[32949:1669571] [Firebase/Crashlytics] Version 8.15.0</span></p>
        """

        var inputData = Data(input.utf8)
        let targetSize = Data(expectedOutput.utf8).count
        let trimmer = LogsTrimmer()

        XCTAssertTrue(trimmer.trim(data: &inputData, maximumSize: targetSize, targetSize: targetSize))

        let outputString = String(data: inputData, encoding: .utf8)
        XCTAssertEqual(outputString, expectedOutput)
    }

    func testTrimmingLargeHTMLLogDropsToTargetAndKeepsNewestEntries() {
        var input = sessionHeader
        for index in 0..<100 {
            input += htmlLogLine(message: "entry-\(index)")
        }

        var inputData = Data(input.utf8)
        let targetSize = inputData.count * 3 / 4
        let trimmer = LogsTrimmer()

        XCTAssertTrue(trimmer.trim(data: &inputData, maximumSize: inputData.count - 1, targetSize: targetSize))

        let outputString = String(decoding: inputData, as: UTF8.self)
        XCTAssertLessThanOrEqual(inputData.count, targetSize)
        XCTAssertTrue(outputString.contains("class=\"session-header\""))
        XCTAssertFalse(outputString.contains("entry-0"))
        XCTAssertTrue(outputString.contains("entry-99"))
    }

    func testFallbackTrimsPlainLogsOnLineBoundaryWhenHTMLLogsCannotBoundFile() {
        let input = (0..<100)
            .map { "plain-log-entry-\($0)-\(String(repeating: "x", count: 20))" }
            .joined(separator: "\n") + "\n"

        var inputData = Data(input.utf8)
        let targetSize = inputData.count / 2
        let trimmer = LogsTrimmer()

        XCTAssertTrue(trimmer.trim(data: &inputData, maximumSize: targetSize, targetSize: targetSize))

        let outputString = String(decoding: inputData, as: UTF8.self)
        XCTAssertLessThanOrEqual(inputData.count, targetSize)
        XCTAssertTrue(outputString.hasPrefix("plain-log-entry-"))
        XCTAssertFalse(outputString.contains("plain-log-entry-0-"))
        XCTAssertTrue(outputString.contains("plain-log-entry-99-"))
    }
}

private let sessionHeader = """
<summary><div class="session-header"><p><span>Date: </span>2024-02-20 10:33:47</p><p><span>System: </span>iOS 16.3</p><p><span>Locale: </span>en-GB</p><p><span>Version: </span>6.2.8 (17000)</p></div></summary>
"""

private func htmlLogLine(message: String) -> String {
    """
    <p class="system"><span class="log-date">2024-02-20 10:33:47</span><span class="log-separator"> | </span><span class="log-message">SYSTEM: \(message)</span></p>
    """
}
//  swiftlint:enable line_length

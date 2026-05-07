//
//  LogsTrimmer.swift
//
//
//  Created by Antoine van der Lee on 01/03/2024.
//

import Foundation

struct LogsTrimmer: Sendable {
    fileprivate static let htmlLogPrefix = Array("<p class=\"".utf8)
    fileprivate static let htmlLogSuffix = Array("</p>".utf8)
    fileprivate static let newline = UInt8(ascii: "\n")

    func trim(data: inout Data, maximumSize: Int, targetSize: Int) -> Bool {
        guard maximumSize >= 0, data.count > maximumSize else {
            return false
        }

        let targetSize = min(max(targetSize, 0), maximumSize)
        if let trimmedData = data.trimmingOldestHTMLLogRecords(toTargetSize: targetSize) {
            data = trimmedData
            return true
        }

        guard let trimmedData = data.trimmingOldestContent(toTargetSize: targetSize) else {
            return false
        }

        data = trimmedData
        return true
    }
}

private extension Data {
    func trimmingOldestHTMLLogRecords(toTargetSize targetSize: Int) -> Data? {
        var rangesToRemove: [Range<Index>] = []
        var remainingSize = count
        var searchStartIndex = startIndex

        while searchStartIndex < endIndex {
            guard let prefixRange = firstRange(of: LogsTrimmer.htmlLogPrefix, in: searchStartIndex..<endIndex) else {
                break
            }
            guard let suffixRange = firstRange(of: LogsTrimmer.htmlLogSuffix, in: prefixRange.upperBound..<endIndex) else {
                break
            }

            let recordRange = prefixRange.lowerBound..<suffixRange.upperBound
            if let lastRange = rangesToRemove.last,
               containsOnlyLineBreaks(in: lastRange.upperBound..<recordRange.lowerBound) {
                let gapRange = lastRange.upperBound..<recordRange.lowerBound
                rangesToRemove[rangesToRemove.count - 1] = lastRange.lowerBound..<recordRange.upperBound
                remainingSize -= gapRange.count + recordRange.count
            } else {
                rangesToRemove.append(recordRange)
                remainingSize -= recordRange.count
            }
            if remainingSize <= targetSize {
                break
            }

            searchStartIndex = suffixRange.upperBound
        }

        guard !rangesToRemove.isEmpty, remainingSize <= targetSize else {
            return nil
        }

        var trimmedData = self
        for range in rangesToRemove.reversed() {
            trimmedData.removeSubrange(range)
        }
        return trimmedData
    }

    func trimmingOldestContent(toTargetSize targetSize: Int) -> Data? {
        guard count > targetSize else { return nil }
        guard targetSize > 0 else { return Data() }

        let minimumStartIndex = index(endIndex, offsetBy: -targetSize)
        var index = minimumStartIndex

        while index < endIndex {
            if self[index] == LogsTrimmer.newline {
                let trimEndIndex = self.index(after: index)
                return Data(self[trimEndIndex..<endIndex])
            }
            formIndex(after: &index)
        }

        return Data(suffix(targetSize))
    }

    func containsOnlyLineBreaks(in range: Range<Index>) -> Bool {
        var index = range.lowerBound

        while index < range.upperBound {
            guard self[index] == LogsTrimmer.newline else { return false }
            formIndex(after: &index)
        }

        return true
    }

    func firstRange(of bytes: [UInt8], in searchRange: Range<Index>) -> Range<Index>? {
        guard !bytes.isEmpty, searchRange.count >= bytes.count else { return nil }

        var index = searchRange.lowerBound
        let lastPossibleStartIndex = self.index(searchRange.upperBound, offsetBy: -bytes.count)

        while index <= lastPossibleStartIndex {
            if starts(with: bytes, at: index) {
                return index..<self.index(index, offsetBy: bytes.count)
            }
            formIndex(after: &index)
        }

        return nil
    }

    func starts(with bytes: [UInt8], at startIndex: Index) -> Bool {
        var index = startIndex
        for byte in bytes {
            guard index < endIndex, self[index] == byte else { return false }
            formIndex(after: &index)
        }
        return true
    }
}

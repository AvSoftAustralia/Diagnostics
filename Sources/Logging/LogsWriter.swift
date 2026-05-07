//
//  LogsWriter.swift
//  Diagnostics
//
//  Created by A.J. van der Lee on 01/07/2025.
//

import Foundation

struct LogsWriter {
    let logFileLocation: URL
    let maximumLogSize: Int
    
    func write(_ loggable: Loggable) {
        do {

            let data = loggable.logData

            let fileHandle = try FileHandle(forWritingTo: logFileLocation)
            defer {
                try? fileHandle.close()
            }
            try fileHandle.seekToEnd()
            try fileHandle.write(contentsOf: data)

            let totalFileSize = try fileHandle.offset()
            self.trimLinesIfNecessary(logSize: totalFileSize)
        } catch {
            print("Writing data failed with error: \(error)")
        }
    }
    
    private func trimLinesIfNecessary(logSize: UInt64) {
        guard maximumLogSize >= 0, logSize > UInt64(maximumLogSize) else { return }

        guard
            var data = try? Data(contentsOf: self.logFileLocation, options: .mappedIfSafe),
            !data.isEmpty else {
            return assertionFailure("Trimming the current log file failed")
        }

        let trimmer = LogsTrimmer()
        let targetLogSize = maximumLogSize * 3 / 4
        guard trimmer.trim(data: &data, maximumSize: maximumLogSize, targetSize: targetLogSize) else { return }

        guard (try? data.write(to: logFileLocation, options: .atomic)) != nil else {
            return assertionFailure("Could not write trimmed log to target file location: \(logFileLocation)")
        }
    }
}

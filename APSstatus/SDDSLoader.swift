import Foundation
import Combine
import Gzip

@MainActor
class SDDSLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var extractedData: [(description: String, value: String)] = []

    private let urlString = "https://ops.aps.anl.gov/sddsStatus/mainStatus.sdds.gz"

    func fetchStatus() {
        guard let url = URL(string: urlString) else {
            statusText = "Invalid URL"
            return
        }

        Task {
            do {
                let (compressedData, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    statusText = "Failed to download file"
                    return
                }

                let decompressedData = try compressedData.gunzipped()
                try parseSDDS(decompressedData)

                statusText = "Loaded SDDS (\(extractedData.count) items)"
            } catch {
                statusText = "Error: \(error.localizedDescription)"
            }
        }
    }

    private func parseSDDS(_ data: Data) throws {
        var offset = 0

        // 1️⃣ Read header lines until &data
        var headerLines: [String] = []
        while true {
            guard let range = data[offset...].firstIndex(of: 0x0A) else { break }
            let lineData = data[offset..<range]
            let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            headerLines.append(line)
            offset = range + 1
            if line.lowercased().starts(with: "&data") { break }
        }

        // 2️⃣ Extract column names
        let columns: [String] = headerLines.compactMap { line in
            let l = line.lowercased()
            guard l.starts(with: "&column") else { return nil }
            if let namePart = line.split(separator: "=").dropFirst().first {
                return namePart.split(separator: ",").first?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return nil
        }

        guard !columns.isEmpty else {
            throw NSError(domain: "SDDSLoader", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No columns found"])
        }

        // 3️⃣ Skip whitespace before binary block
        while offset < data.count {
            let byte = data[offset]
            if ![0x20, 0x09, 0x0A, 0x0D].contains(byte) { break }
            offset += 1
        }

        // 4️⃣ Read number of rows (safe, unaligned)
        guard offset + 4 <= data.count else {
            throw NSError(domain: "SDDSLoader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot read nrows"])
        }
        let nrows: Int = {
            let b0 = UInt32(data[offset])
            let b1 = UInt32(data[offset + 1])
            let b2 = UInt32(data[offset + 2])
            let b3 = UInt32(data[offset + 3])
            return Int(b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
        }()
        offset += 4

        // 5️⃣ Read each column
        var columnData: [String: [String]] = [:]
        for col in columns { columnData[col] = [] }

        // SDDS binary format stores strings as: [length (Int32)][UTF8 bytes]
        for _ in 0..<nrows {
            for col in columns {
                guard offset + 4 <= data.count else { continue }
                let lenData = data[offset..<offset+4]
                let strLen: Int = Int(lenData[lenData.startIndex] |
                                      lenData[lenData.startIndex+1] << 8 |
                                      lenData[lenData.startIndex+2] << 16 |
                                      lenData[lenData.startIndex+3] << 24)
                offset += 4

                guard offset + strLen <= data.count else { continue }
                let strData = data[offset..<offset+strLen]
                let value = String(data: strData, encoding: .utf8) ?? ""
                offset += strLen

                columnData[col]?.append(value)
            }
        }

        // 6️⃣ Select the parameters like Python script
        let selectedNames: [String] = [
            "Current",
            "ScheduledMode",
            "ActualMode",
            "TopupState",
            "InjOperation",
            "ShutterStatus",
            "UpdateTime",
            "RTFBStatus",
            "OPSMessage1",
            "OPSMessage2",
            "OPSMessage3",
            "BM2ShutterClosed",
            "BM7ShutterClosed",
            "ID32ShutterClosed"
        ]

        var results: [(String, String)] = []
        guard let descs = columnData["Description"], let vals = columnData["ValueString"] else {
            extractedData = []
            return
        }

        // Loop over selected names in order, find all matching rows
        for name in selectedNames {
            for (idx, desc) in descs.enumerated() {
                if desc == name {
                    results.append((desc, vals[idx]))
                    break // take the first match per parameter
                }
            }
        }

        extractedData = results

    }
}

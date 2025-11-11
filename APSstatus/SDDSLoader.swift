import Foundation
import Combine
import Gzip

@MainActor
class SDDSLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var columns: [String] = []
    @Published var dataDict: [String: [Double]] = [:] // column -> array of values

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

                statusText = "Loaded SDDS (\(columns.count) columns, \(dataDict.first?.value.count ?? 0) rows)"
            } catch {
                statusText = "Error: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Parse SDDS
    private func parseSDDS(_ data: Data) throws {
        var offset = 0

        // 1️⃣ Read header lines until &data
        var headerLines: [String] = []
        while true {
            guard let range = data[offset...].firstIndex(of: 0x0A) else { break } // newline
            let lineData = data[offset..<range]
            let line = String(data: lineData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            headerLines.append(line)
            offset = range + 1
            if line.lowercased().starts(with: "&data") { break }
        }

        // 2️⃣ Extract column names
        columns = headerLines.compactMap { line in
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

        // 4️⃣ Read number of rows (int32, little-endian) safely
        guard offset + 4 <= data.count else {
            throw NSError(domain: "SDDSLoader", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Cannot read nrows"])
        }
        let nrowsData = data[offset..<offset+4]
        let nrows = Int(
            Int32(
                nrowsData[nrowsData.startIndex] |
                nrowsData[nrowsData.startIndex+1] << 8 |
                nrowsData[nrowsData.startIndex+2] << 16 |
                nrowsData[nrowsData.startIndex+3] << 24
            )
        )
        offset += 4

        // 5️⃣ Read doubles safely
        let ncols = columns.count
        let expectedBytes = nrows * ncols * MemoryLayout<Double>.size
        guard offset + expectedBytes <= data.count else {
            throw NSError(domain: "SDDSLoader", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "Binary size mismatch"])
        }

        var columnData: [String: [Double]] = [:]
        for col in columns { columnData[col] = [] }

        for row in 0..<nrows {
            for colIndex in 0..<ncols {
                let start = offset + (row * ncols + colIndex) * MemoryLayout<Double>.size
                let end = start + MemoryLayout<Double>.size
                let dData = data[start..<end]

                // reconstruct double from little-endian bytes safely
                let bitPattern = UInt64(dData[dData.startIndex]) |
                                 UInt64(dData[dData.startIndex+1]) << 8 |
                                 UInt64(dData[dData.startIndex+2]) << 16 |
                                 UInt64(dData[dData.startIndex+3]) << 24 |
                                 UInt64(dData[dData.startIndex+4]) << 32 |
                                 UInt64(dData[dData.startIndex+5]) << 40 |
                                 UInt64(dData[dData.startIndex+6]) << 48 |
                                 UInt64(dData[dData.startIndex+7]) << 56
                let val = Double(bitPattern: bitPattern)

                columnData[columns[colIndex], default: []].append(val)
            }
        }

        dataDict = columnData
    }
}

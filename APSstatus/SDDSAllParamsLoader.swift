//
//  Untitled.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/14/25.
//

import Foundation
import Combine
import Gzip

@MainActor
final class SDDSAllParamsLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var items: [(description: String, value: String)] = []

    private let urlString: String

    init(urlString: String) {
        self.urlString = urlString
    }

    func fetchStatus() {
        guard let url = URL(string: urlString) else {
            statusText = "Invalid URL"
            return
        }

        Task {
            do {
                let (compressedData, response) = try await URLSession.shared.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    statusText = "Failed to download file"
                    return
                }

                let decompressedData = try compressedData.gunzipped()
                try parseSDDS(decompressedData)
                statusText = "Loaded SDDS (\(items.count) items)"
            } catch {
                statusText = "Error: \(error.localizedDescription)"
                print("Detailed error: \(error)")
            }
        }
    }

    private func parseSDDS(_ data: Data) throws {
        var offset = 0

        // Read header lines until &data
        var headerLines: [String] = []
        while offset < data.count {
            guard let nl = data[offset...].firstIndex(of: 0x0A) else { break }
            let lineData = data[offset..<nl]
            let line = String(data: lineData, encoding: .utf8) ?? ""
            headerLines.append(line)
            offset = nl + 1
            if line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().hasPrefix("&data") {
                break
            }
        }

        // Helper to extract defs (&parameter, &array, &column) with name and type
        struct Def { let name: String; let type: String? }
        func extractDefs(prefix: String) -> [Def] {
            var defs: [Def] = []
            for line in headerLines {
                if !line.lowercased().hasPrefix(prefix) { continue }
                let name = extractAttr(from: line, key: "name")
                let type = extractAttr(from: line, key: "type")?.lowercased()
                defs.append(Def(name: name ?? "", type: type))
            }
            return defs
        }
        func extractAttr(from line: String, key: String) -> String? {
            guard let r = line.range(of: "\(key)=", options: .caseInsensitive) else { return nil }
            var s = String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            if s.hasPrefix("\"") {
                let rest = s.dropFirst()
                if let endQ = rest.firstIndex(of: "\"") {
                    return String(rest[..<endQ])
                }
            } else {
                if let comma = s.firstIndex(of: ",") {
                    s = String(s[..<comma])
                }
                return s.trimmingCharacters(in: .whitespaces)
            }
            return nil
        }

        let params  = extractDefs(prefix: "&parameter")
        let arrays  = extractDefs(prefix: "&array")
        let columns = extractDefs(prefix: "&column")

        guard !columns.isEmpty else {
            throw NSError(domain: "SDDSAllParamsLoader", code: 100, userInfo: [NSLocalizedDescriptionKey: "No columns found"])
        }

        // Skip whitespace before binary block
        while offset < data.count, [0x20, 0x09, 0x0A, 0x0D].contains(data[offset]) { offset += 1 }

        // Read nrows (Int32 LE)
        guard offset + 4 <= data.count else { throw err("Cannot read nrows") }
        let nrows: Int32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
        offset += 4
        guard nrows >= 0 && nrows < 1_000_000 else { throw err("Invalid nrows \(nrows)") }

        // Functions for reading/skipping values
        func readI32() throws -> Int32 {
            guard offset + 4 <= data.count else { throw err("Unexpected EOF reading Int32") }
            let v: Int32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
            offset += 4
            return v
        }
        func readString() throws -> String {
            let L = try readI32()
            guard L >= 0, offset + Int(L) <= data.count else { throw err("Invalid string length \(L)") }
            let s = String(data: data[offset..<offset+Int(L)], encoding: .utf8) ?? ""
            offset += Int(L)
            return s
        }
        func skipNumericBytes(for type: String) throws {
            let sizeMap: [String: Int] = [
                "double": 8, "float": 4, "long": 4, "short": 2,
                "char": 1, "uchar": 1, "ulong": 4, "ushort": 2,
                "longlong": 8, "ulonglong": 8
            ]
            guard let sz = sizeMap[type] else { throw err("Unknown numeric type \(type)") }
            guard offset + sz <= data.count else { throw err("Unexpected EOF skipping \(type)") }
            offset += sz
        }

        // 1) Read/skip parameter values (header &parameter entries)
        for p in params {
            if (p.type ?? "") == "string" {
                _ = try readString()
            } else if let t = p.type {
                try skipNumericBytes(for: t)
            } else {
                throw err("Parameter \(p.name) missing type")
            }
        }

        // 2) Read/skip arrays (header &array entries)
        for a in arrays {
            let count = try readI32()
            if (a.type ?? "") == "string" {
                for _ in 0..<count { _ = try readString() }
            } else if let t = a.type {
                let sizeMap: [String: Int] = [
                    "double": 8, "float": 4, "long": 4, "short": 2,
                    "char": 1, "uchar": 1, "ulong": 4, "ushort": 2,
                    "longlong": 8, "ulonglong": 8
                ]
                guard let sz = sizeMap[t] else { throw err("Unknown array type \(t)") }
                let bytes = Int(count) * sz
                guard offset + bytes <= data.count else { throw err("Unexpected EOF skipping array \(a.name)") }
                offset += bytes
            } else {
                throw err("Array \(a.name) missing type")
            }
        }

        // 3) Read table rows and collect Description -> ValueString for all rows
        var columnData: [String: [String]] = [:]
        for c in columns { columnData[c.name] = [] }

        for _ in 0..<Int(nrows) {
            for c in columns {
                if (c.type ?? "") == "string" {
                    let v = try readString()
                    columnData[c.name]?.append(v)
                } else if let t = c.type {
                    let sizeMap: [String: Int] = [
                        "double": 8, "float": 4, "long": 4, "short": 2,
                        "char": 1, "uchar": 1, "ulong": 4, "ushort": 2,
                        "longlong": 8, "ulonglong": 8
                    ]
                    guard let sz = sizeMap[t] else { throw err("Unknown column type \(c.name): \(t)") }
                    guard offset + sz <= data.count else { throw err("Unexpected EOF in column \(c.name)") }
                    offset += sz
                } else {
                    throw err("Column \(c.name) missing type")
                }
            }
        }

        guard let descs = columnData["Description"], let vals = columnData["ValueString"] else {
            print("Missing Description or ValueString. Available: \(Array(columnData.keys))")
            items = []
            return
        }

        // Keep all rows in original order (allow duplicates)
        var results: [(String, String)] = []
        for i in 0..<descs.count {
            results.append((descs[i].trimmingCharacters(in: .whitespacesAndNewlines), vals[i]))
        }

        items = results
    }

    private func err(_ msg: String) -> NSError {
        NSError(domain: "SDDSAllParamsLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

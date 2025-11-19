//
//  SDDSParser.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/18/25.
//

import Foundation

enum SDDSParser {
    static func parseMainStatusItems(_ data: Data) throws -> [(description: String, value: String)] {
        var offset = 0

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

        guard !columns.isEmpty else { throw err("No columns found") }

        // Skip whitespace
        while offset < data.count, [0x20, 0x09, 0x0A, 0x0D].contains(data[offset]) { offset += 1 }

        // Number of rows
        guard offset + 4 <= data.count else { throw err("Cannot read nrows") }
        let nrows: Int32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
        offset += 4
        guard nrows >= 0 && nrows < 1_000_000 else { throw err("Invalid nrows \(nrows)") }

        func readI32() throws -> Int32 {
            guard offset + 4 <= data.count else { throw err("Unexpected EOF reading Int32") }
            let v: Int32 = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: Int32.self) }
            offset += 4
            return v
        }
        func readString() throws -> String {
            let L = try readI32()
            guard L >= 0, offset + Int(L) <= data.count else { throw err("Invalid string length \(L)") }
            let s = String(data: data[offset..<(offset+Int(L))], encoding: .utf8) ?? ""
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

        // Parameters
        for p in params {
            if (p.type ?? "") == "string" {
                _ = try readString()
            } else if let t = p.type {
                try skipNumericBytes(for: t)
            } else {
                throw err("Parameter \(p.name) missing type")
            }
        }

        // Arrays
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

        // Columns
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

        // Filter desired rows
        let baseSelected: Set<String> = [
            "Current","ScheduledMode","ActualMode","TopupState","InjOperation",
            "ShutterStatus","UpdateTime","OPSMessage1","OPSMessage2",
            "OPSMessage3","OPSMessage4","OPSMessage5","Lifetime"
        ]

        // Include both padded (BM01/ID01) and non-padded (BM1/ID1) shutter keys
        let shutterKeys: Set<String> = Set((1...35).flatMap { i -> [String] in
            let p = String(format: "%02d", i)
            return [
                "ID\(i)ShutterClosed",  "BM\(i)ShutterClosed",
                "ID\(p)ShutterClosed",  "BM\(p)ShutterClosed"
            ]
        })
        let selectedNames = baseSelected.union(shutterKeys)

        guard
            let descs = columnData["Description"],
            let vals  = columnData["ValueString"]
        else {
            throw err("Missing Description or ValueString")
        }

        var found = Set<String>()
        var results: [(String, String)] = []
        for (i, d) in descs.enumerated() {
            let key = d.trimmingCharacters(in: .whitespacesAndNewlines)
            if selectedNames.contains(key), !found.contains(key) {
                results.append((key, vals[i]))
                found.insert(key)
            }
        }

        return results
    }

    private static func err(_ msg: String) -> NSError {
        NSError(domain: "SDDSStatusLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
    }
}

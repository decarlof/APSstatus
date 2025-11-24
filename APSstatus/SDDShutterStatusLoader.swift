import Foundation
import Combine
import Gzip
import SwiftUI

@MainActor
final class SDDSShutterStatusLoader: ObservableObject {
    @Published var statusText: String = "Loading…"
    @Published var extractedData: [(description: String, value: String)] = []
    
    // Beam-ready map from PssData: Description -> ValueString ("ON"/"OFF"/...)
    @Published var beamReadyMap: [String: String] = [:]

    private let mainStatusURL = "https://ops.aps.anl.gov/sddsStatus/mainStatus.sdds.gz"
    private let pssDataURL    = "https://ops.aps.anl.gov/sddsStatus/PssData.sdds.gz"

    // MARK: - Public API

    func fetchStatus() {
        guard let url = URL(string: mainStatusURL) else {
            statusText = "Invalid mainStatus URL"
            return
        }

        Task {
            do {
                // 1) Load mainStatus
                let (compressedData, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    statusText = "Failed to download mainStatus (status \(http.statusCode))"
                    return
                }

                // Decompress + parse mainStatus off the main thread
                let parsedItems = try await Task.detached(priority: .userInitiated) { () -> [(String, String)] in
                    let decompressed = try compressedData.gunzipped()
                    return try SDDSShutterStatusLoader.parseMainStatusItems(decompressed)
                }.value

                // 2) In parallel, try to load PssData (beam ready info).
                //    If it fails, we just leave beamReadyMap empty (dots will be black).
                Task.detached(priority: .background) { [weak self] in
                    await self?.loadPssBeamReady()
                }

                // Publish main status data on main actor
                self.extractedData = parsedItems
                self.statusText = "Loaded SDDS (\(parsedItems.count) items)"
            } catch {
                self.statusText = "Error: \(error.localizedDescription)"
                print("Detailed error (mainStatus): \(error)")
            }
        }
    }

    // Optional: explicit refresh of PSS only
    func refreshPss() {
        Task {
            await loadPssBeamReady()
        }
    }

    // MARK: - Helper for the UI: beam-ready dot color for a shutter key

    // UPDATED: now also depends on shutterValue (open/closed)
    func beamReadyDotColor(forShutterKey shutterKey: String,
                           shutterValue: String) -> Color {
        // shutterKey example: "BM01ShutterClosed", "ID7ShutterClosed"
        guard (shutterKey.hasPrefix("BM") || shutterKey.hasPrefix("ID")),
              shutterKey.hasSuffix("ShutterClosed") else {
            return .black
        }

        let prefix = String(shutterKey.prefix(2))  // "BM" or "ID"
        var numberPart = shutterKey.dropFirst(2)
        if let r = numberPart.range(of: "ShutterClosed") {
            numberPart = numberPart[..<r.lowerBound]
        }
        let numberString = String(numberPart)

        // Special cases: BM06 and BM35 should always be black (bad/unused StaASearchedPl)
        if prefix == "BM",
           numberString == "6"  || numberString == "06" ||
           numberString == "35" || numberString == "35" {
            return .yellow
        }

        guard let n = Int(numberString) else {
            return .black
        }

        // Determine if shutter is open or closed from shutterValue ("ON"/"OFF"/...)
        // Assumption (consistent with your UI): "ON" = shutter CLOSED, "OFF" = shutter OPEN
        let shutterState = shutterValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // Try both zero-padded and non-padded variants for PSS map keys
        let padded = String(format: "%02d", n)
        let candidates = [
            "\(prefix)\(padded)StaASearchedPl",
            "\(prefix)\(n)StaASearchedPl"
        ]

        // Read PSS beam-ready status
        var pssRaw: String? = nil
        for key in candidates {
            if let raw = beamReadyMap[key]?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                pssRaw = raw
                break
            }
        }

        // No PSS entry → black dot (rule 4)
        guard let pss = pssRaw else {
            return .black
        }

        // If shutter is OPEN, dot uses same color as shutter open (magenta) – rule 1
        if shutterState == "OFF" {
            // Same color as shutterColor(for:) uses for "OFF"
            return Color(red: 0.9, green: 0.0, blue: 0.9)
        }

        // Shutter is CLOSED → dot shows beam-ready state – rules 2 and 3
        switch pss {
        case "ON":
            // Beam ready → green
            return .green
        case "OFF":
            // Beam not ready → red
            return .red
        default:
            // Unknown value → black
            return .black
        }
    }

    // MARK: - Internal: load PssData and update beamReadyMap

    private func loadPssBeamReady() async {
        guard let url = URL(string: pssDataURL) else {
            print("Invalid PssData URL")
            return
        }

        do {
            let (compressedData, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                print("Failed to download PssData (status \(http.statusCode))")
                return
            }

            // Decompress + parse off main thread
            let beamMap = try await Task.detached(priority: .userInitiated) { () -> [String: String] in
                let decompressed = try compressedData.gunzipped()
                return try SDDSShutterStatusLoader.parsePssBeamReadyItems(decompressed)
            }.value

            // Update on main actor
            await MainActor.run {
                self.beamReadyMap = beamMap
            }
        } catch {
            print("Error loading PssData: \(error)")
        }
    }

    // MARK: - Nonisolated parsers (safe to call from Task.detached)

    nonisolated static func parseMainStatusItems(_ data: Data) throws -> [(description: String, value: String)] {
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

        func err(_ msg: String) -> NSError {
            NSError(domain: "SDDSStatusLoader", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let params  = extractDefs(prefix: "&parameter")
        let arrays  = extractDefs(prefix: "&array")
        let columns = extractDefs(prefix: "&column")

        guard !columns.isEmpty else {
            throw NSError(domain: "SDDSStatusLoader", code: 100, userInfo: [NSLocalizedDescriptionKey: "No columns found"])
        }

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

    // Parse PssData.sdds.gz into [Description : ValueString]
    nonisolated static func parsePssBeamReadyItems(_ data: Data) throws -> [String: String] {
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

        func err(_ msg: String) -> NSError {
            NSError(domain: "SDDSStatusLoader-PSS", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])
        }

        let params  = extractDefs(prefix: "&parameter")
        let arrays  = extractDefs(prefix: "&array")
        let columns = extractDefs(prefix: "&column")

        guard !columns.isEmpty else {
            throw NSError(domain: "SDDSStatusLoader-PSS", code: 100, userInfo: [NSLocalizedDescriptionKey: "No columns found"])
        }

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

        guard
            let descs = columnData["Description"],
            let vals  = columnData["ValueString"]
        else {
            throw err("Missing Description or ValueString")
        }

        var result: [String: String] = [:]
        for i in 0..<descs.count {
            let key   = descs[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = vals[i].trimmingCharacters(in: .whitespacesAndNewlines)
            result[key] = value
        }

        return result
    }
    
}

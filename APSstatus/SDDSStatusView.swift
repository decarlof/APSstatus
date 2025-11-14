import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSLoader()

    // Map SDDS Description -> Friendly label (static entries)
    private let displayName: [String: String] = [
        "ScheduledMode":  "Scheduled Mode",
        "ActualMode":     "Actual Mode",
        "TopupState":     "Top-up",
        "InjOperation":   "Injector",
        "ShutterStatus":  "Shutters",
        "UpdateTime":     "Updated",
        "OPSMessage1":    "MCR Crew",
        "OPSMessage2":    "Floor Coord",
        "OPSMessage3":    "Fill Pattern",
        "OPSMessage4":    "Last Dump/Trip",
        "OPSMessage5":    "Problem Info",
        "Current":        "Current",
        "Lifetime":       "Lifetime"
    ]

    // Desired order by ORIGINAL SDDS keys (Description)
    private let orderByKey = [
        "Current",
        "Lifetime",
        "TopupState",
        "InjOperation",
        "ScheduledMode",
        "ActualMode",
        "ShutterStatus",
        "OPSMessage3", // Fill Pattern
        "OPSMessage1", // MCR Crew
        "OPSMessage2", // Floor Coord
        "OPSMessage4", // Last Dump/Trip
        "OPSMessage5", // Problem Info
        "UpdateTime"
        // ShutterClosed keys (IDxx/BMxx) are placed after UpdateTime by custom ranking
    ]

    private var keyRank: [String: Int] {
        Dictionary(uniqueKeysWithValues: orderByKey.enumerated().map { ($1, $0) })
    }

    // Compute a precise position for shutter keys:
    // BM1, ID1, BM2, ID2, ..., BM35, ID35 (all after UpdateTime).
    private func shutterPosition(for key: String) -> Int? {
        guard (key.hasPrefix("BM") || key.hasPrefix("ID")),
              key.hasSuffix("ShutterClosed") else { return nil }

        let prefix = String(key.prefix(2)) // "BM" or "ID"
        let numberPart = key.dropFirst(2).replacingOccurrences(of: "ShutterClosed", with: "")
        guard let n = Int(numberPart), n >= 1 else { return nil }

        // Base immediately after UpdateTime
        let base = (keyRank["UpdateTime"] ?? 0) + 1
        // BMn first, then IDn
        let offset = (n - 1) * 2 + (prefix == "BM" ? 0 : 1)
        return base + offset
    }

    private func rank(for key: String) -> Int {
        if let r = keyRank[key] { return r }
        if let sp = shutterPosition(for: key) { return sp }
        return Int.max
    }

    private func isShutterKey(_ key: String) -> Bool {
        (key.hasPrefix("ID") || key.hasPrefix("BM")) && key.hasSuffix("ShutterClosed")
    }

    private func friendlyName(for key: String) -> String {
        // Show IDxx or BMxx by removing "ShutterClosed"
        if isShutterKey(key) {
            return key.replacingOccurrences(of: "ShutterClosed", with: "")
        }
        return displayName[key] ?? key
    }

    private var sortedItems: [(description: String, value: String)] {
        // Filter out BM/ID shutters that are "_NoConnection_"
        let filtered = loader.extractedData.filter { item in
            if isShutterKey(item.description) {
                let v = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
                return v != "_NoConnection_"
            }
            return true
        }

        return filtered.sorted { a, b in
            let ia = rank(for: a.description)
            let ib = rank(for: b.description)
            if ia != ib { return ia < ib }
            return a.description < b.description
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if loader.extractedData.isEmpty {
                    Text(loader.statusText)
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear { loader.fetchStatus() }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sortedItems, id: \.description) { item in
                                HStack {
                                    Text(friendlyName(for: item.description) + ":")
                                        .fontWeight(.semibold)
                                    Spacer()

                                    // Color "Current" value based on threshold
                                    if item.description == "Current",
                                       let currentValue = Double(item.value) {
                                        Text(item.value)
                                            .foregroundColor(currentValue > 100 ? .green : .red)
                                            .fontWeight(.bold)
                                    } else {
                                        Text(item.value)
                                    }
                                }
                                Divider()

                                // Separator after "Fill Pattern"
                                if item.description == "OPSMessage3" {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(height: 2)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") { loader.fetchStatus() }
                }
            }
        }
    }
}

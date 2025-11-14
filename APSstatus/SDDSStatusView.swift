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
        // ShutterClosed keys (IDxx/BMxx) will be displayed as a grid after UpdateTime
    ]

    private var keyRank: [String: Int] {
        Dictionary(uniqueKeysWithValues: orderByKey.enumerated().map { ($1, $0) })
    }

    private func isShutterKey(_ key: String) -> Bool {
        (key.hasPrefix("ID") || key.hasPrefix("BM")) && key.hasSuffix("ShutterClosed")
    }

    // BM1, ID1, BM2, ID2, ..., BM35, ID35 (ordered after UpdateTime base)
    private func shutterPosition(for key: String) -> Int? {
        guard (key.hasPrefix("BM") || key.hasPrefix("ID")),
              key.hasSuffix("ShutterClosed") else { return nil }

        let prefix = String(key.prefix(2)) // "BM" or "ID"
        let numberPart = key.dropFirst(2).replacingOccurrences(of: "ShutterClosed", with: "")
        guard let n = Int(numberPart), n >= 1 else { return nil }

        let base = (keyRank["UpdateTime"] ?? 0) + 1
        let offset = (n - 1) * 2 + (prefix == "BM" ? 0 : 1)
        return base + offset
    }

    private func rank(for key: String) -> Int {
        if let r = keyRank[key] { return r }
        if let sp = shutterPosition(for: key) { return sp }
        return Int.max
    }

    private func friendlyName(for key: String) -> String {
        // Show IDxx or BMxx by removing "ShutterClosed"
        if isShutterKey(key) {
            return key.replacingOccurrences(of: "ShutterClosed", with: "")
        }
        return displayName[key] ?? key
    }

    // Non-shutter items, sorted as before
    private var nonShutterItems: [(description: String, value: String)] {
        loader.extractedData
            .filter { !isShutterKey($0.description) }
            .sorted { a, b in
                let ia = rank(for: a.description)
                let ib = rank(for: b.description)
                if ia != ib { return ia < ib }
                return a.description < b.description
            }
    }

    // Shutter items (BM/ID), filtered and ordered BM1, ID1, ..., BM35, ID35
    private var shutterItemsOrdered: [(description: String, value: String)] {
        loader.extractedData
            .filter { item in
                // Keep only BM/ID shutter keys and drop _NoConnection_
                guard isShutterKey(item.description) else { return false }
                let v = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
                return v != "_NoConnection_"
            }
            .sorted { a, b in
                let ia = shutterPosition(for: a.description) ?? Int.max
                let ib = shutterPosition(for: b.description) ?? Int.max
                if ia != ib { return ia < ib }
                return a.description < b.description
            }
    }

    private func shutterColor(for value: String) -> Color {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch v {
        case "ON":  return .green
        case "OFF": return .red
        default:    return .gray.opacity(0.5) // fallback if unexpected value
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if loader.extractedData.isEmpty {
                        Text(loader.statusText)
                            .foregroundColor(.gray)
                            .padding()
                            .onAppear { loader.fetchStatus() }
                    } else {
                        // Standard list items (non-shutter)
                        ForEach(nonShutterItems, id: \.description) { item in
                            HStack {
                                Text((displayName[item.description] ?? item.description) + ":")
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

                        // Shutter grid (BM/ID rectangles)
                        if !shutterItemsOrdered.isEmpty {
                            // 6 columns; rows will wrap automatically
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                            Rectangle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(height: 2)
                                .padding(.vertical, 6)

                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(shutterItemsOrdered, id: \.description) { item in
                                    let label = friendlyName(for: item.description)
                                    let color = shutterColor(for: item.value)

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(color)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(Color.black.opacity(0.2), lineWidth: 1)
                                            )

                                        Text(label)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                    }
                                    .frame(height: 34) // identical height; width set by grid column
                                    .accessibilityLabel("\(label) \(item.value)")
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
            // Pull-to-refresh
            .refreshable {
                // Triggers network reload; fetchStatus manages its own async Task
                loader.fetchStatus()
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

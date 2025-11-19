import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSStatusLoader()

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

    // Less-bright magenta to indicate X-rays in station (OFF/open shutter)
    private let xrMagenta = Color(hue: 0.83, saturation: 0.55, brightness: 0.58)

    private var keyRank: [String: Int] {
        Dictionary(uniqueKeysWithValues: orderByKey.enumerated().map { ($1, $0) })
    }

    private func isShutterKey(_ key: String) -> Bool {
        (key.hasPrefix("ID") || key.hasPrefix("BM")) && key.hasSuffix("ShutterClosed")
    }

    // BM1, ID1, BM2, ID2, ..., BM35, ID35 (ordered after UpdateTime base).
    // This handles both zero-padded (BM01) and non-padded (BM1).
    private func shutterPosition(for key: String) -> Int? {
        guard (key.hasPrefix("BM") || key.hasPrefix("ID")),
              key.hasSuffix("ShutterClosed") else { return nil }

        let prefix = String(key.prefix(2)) // "BM" or "ID"
        var numberPart = key.dropFirst(2)
        if let r = numberPart.range(of: "ShutterClosed") {
            numberPart = numberPart[..<r.lowerBound]
        }
        let s = String(numberPart)
        guard let n = Int(s), n >= 1 else { return nil }

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

    // Shutter color: ON -> green, OFF -> magenta
    // Note the logic ON/OFF is flipped. ON = shutter closes, OFF = shutter open
    // this was done to maintain compatibility withe Android version using the same mainStatus.sdds.gz file
    private func shutterColor(for value: String) -> Color {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch v {
        case "ON":  return .green
        case "OFF": return Color(red: 0.9, green: 0.0, blue: 0.9) // magenta
        default:    return .gray.opacity(0.5)
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
                        // Non-shutter list, enumerated so we can avoid trailing divider
                        ForEach(Array(nonShutterItems.enumerated()), id: \.element.description) { idx, item in
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

                            // Draw divider only between rows, not after the last one
                            if idx < nonShutterItems.count - 1 {
                                Divider()
                            }

                            // Special thicker separator after "Fill Pattern" if desired
                            if item.description == "OPSMessage3" {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(height: 2)
                                    .padding(.vertical, 4)
                            }
                        }

                        // Shutter grid (BM/ID rectangles)
                        if !shutterItemsOrdered.isEmpty {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                            // Single divider before the shutter section
                            Divider()
                                .padding(.vertical, 6)

                            Text("Shutter status")
                                .font(.headline)
                                .padding(.bottom, 4)

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
                                    .frame(height: 34)
                                    .accessibilityLabel("\(label) \(item.value)")
                                }
                            }
                            .padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                loader.fetchStatus()
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

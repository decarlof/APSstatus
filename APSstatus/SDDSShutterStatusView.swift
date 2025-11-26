import SwiftUI

struct SDDSShutterStatusView: View { @ObservedObject var loader: SDDSShutterStatusLoader
     
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

    private let orderByKey = [
        "Current",
        "Lifetime",
        "TopupState",
        "InjOperation",
        "ScheduledMode",
        "ActualMode",
        "ShutterStatus",
        "OPSMessage3",
        "OPSMessage1",
        "OPSMessage2",
        "OPSMessage4",
        "OPSMessage5",
        "UpdateTime"
    ]

    private var keyRank: [String: Int] {
        Dictionary(uniqueKeysWithValues: orderByKey.enumerated().map { ($1, $0) })
    }

    private func isShutterKey(_ key: String) -> Bool {
        (key.hasPrefix("ID") || key.hasPrefix("BM")) && key.hasSuffix("ShutterClosed")
    }

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
        // For shutter keys like "BM01ShutterClosed" or "ID7ShutterClosed",
        // convert to "01-BM", "07-ID", etc.
        if isShutterKey(key) {
            let prefix = String(key.prefix(2)) // "BM" or "ID"
            var numberPart = key.dropFirst(2)
            if let r = numberPart.range(of: "ShutterClosed") {
                numberPart = numberPart[..<r.lowerBound]
            }
            let rawNumber = String(numberPart).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let n = Int(rawNumber) else {
                // fallback: old behavior if parsing fails
                return key.replacingOccurrences(of: "ShutterClosed", with: "")
            }
            let padded = String(format: "%02d", n)
            return "\(padded)-\(prefix)"
        }

        // Non-shutter keys use the displayName map or the raw key
        return displayName[key] ?? key
    }
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

    private func shutterColor(for value: String) -> Color {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch v {
        case "ON":  return .green
        case "OFF": return Color(red: 0.9, green: 0.0, blue: 0.9)
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
                            .onAppear {
                                loader.fetchStatus()  // also starts PSS loading internally
                            }
                    } else {
                        ForEach(Array(nonShutterItems.enumerated()), id: \.element.description) { idx, item in
                            HStack {
                                Text((displayName[item.description] ?? item.description) + ":")
                                    .fontWeight(.semibold)
                                Spacer()

                                if item.description == "Current",
                                   let currentValue = Double(item.value) {
                                    Text(item.value)
                                        .foregroundColor(currentValue > 100 ? .green : .red)
                                        .fontWeight(.bold)
                                } else {
                                    Text(item.value)
                                }
                            }

                            if idx < nonShutterItems.count - 1 {
                                Divider()
                            }

                            if item.description == "OPSMessage3" {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.4))
                                    .frame(height: 2)
                                    .padding(.vertical, 4)
                            }
                        }

                        if !shutterItemsOrdered.isEmpty {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                            Divider()
                                .padding(.vertical, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                // Title + shutter state legend
                                HStack(spacing: 12) {
                                    Text("Shutter status")
                                        .font(.headline)

                                    // Legend for shutter rectangles
                                    HStack(spacing: 8) {
                                        // OPEN (magenta)
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(red: 0.9, green: 0.0, blue: 0.9))
                                                .frame(width: 40, height: 18)
                                            Text("open")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }

                                        // CLOSED (green)
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.green)
                                                .frame(width: 50, height: 18)
                                            Text("closed")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
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

                                            HStack {
                                                Text(label)
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)

                                                Spacer(minLength: 2)

                                                Circle()
                                                    .fill(
                                                        loader.beamReadyDotColor(
                                                            forShutterKey: item.description,
                                                            shutterValue: item.value
                                                        )
                                                    )
                                                    .frame(width: 8, height: 8)
                                            }
                                            .padding(.horizontal, 4)
                                        }
                                        .frame(height: 34)
                                        .accessibilityLabel("\(label) \(item.value)")
                                    }
                                }
                                .padding(.top, 4)
                            }

                            // Your existing dot legend comes after this VStack, unchanged
                            VStack(alignment: .leading, spacing: 4) {
                                // Station A NOT searched / NOT secure (shutter closed)
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Station A not searched")
                                        .font(.caption2)
                                }

                                // for debug only
                                // No Station A PSS PV found for this beamline
//                                HStack(spacing: 8) {
//                                    Circle()
//                                        .fill(Color.black)
//                                        .frame(width: 8, height: 8)
//                                    Text("Station A PSS PV missing")
//                                        .font(.caption2)
//                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                loader.fetchStatus()  // will refresh both main and PSS data
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
}

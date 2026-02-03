import SwiftUI

struct SDDSShutterStatusView: View {
    // MARK: - Injected URLs / title

    private let mainStatusURL: String
    private let pssDataURL: String
    private let title: String

    // MAIN status loader
    @StateObject private var loaderMain: SDDSAllParamsLoader
    // PSS data loader
    @StateObject private var loaderPss: SDDSAllParamsLoader

    init(
        mainStatusURL: String,
        pssDataURL: String,
        title: String
    ) {
        self.mainStatusURL = mainStatusURL
        self.pssDataURL = pssDataURL
        self.title = title

        _loaderMain = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: mainStatusURL))
        _loaderPss  = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: pssDataURL))
    }

    // MARK: - Display mapping

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

    // MARK: - Helpers for shutter keys

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
                // fallback if parsing fails
                return key.replacingOccurrences(of: "ShutterClosed", with: "")
            }
            let padded = String(format: "%02d", n)
            return "\(padded)-\(prefix)"
        }

        // Non-shutter keys use the displayName map or the raw key
        return displayName[key] ?? key
    }

    private func isNoConnection(_ value: String) -> Bool {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() == "_NOCONNECTION_"
    }
    // MARK: - Derived data from mainStatus (loaderMain.items)

    /// MainStatus items as a lookup map
    private var mainMap: [String: String] {
        Dictionary(uniqueKeysWithValues: loaderMain.items.map {
            ($0.description.trimmingCharacters(in: .whitespacesAndNewlines),
             $0.value)
        })
    }

    /// Items excluding all shutter PVs, ordered by `rank`.
    private var nonShutterItems: [(description: String, value: String)] {
        let bannedKeys: Set<String> = [
            "BucketsFilled",
            "LocalSteering",
            "RTFBStatus",
            "TopUpEfficiency",
            "NOpenShutters" // exclude from parameter list
        ]

        return loaderMain.items
            .map {
                (description: $0.description.trimmingCharacters(in: .whitespacesAndNewlines),
                 value: $0.value)
            }
            .filter {
                !isShutterKey($0.description) && !bannedKeys.contains($0.description)
            }
            .sorted { a, b in
                let ia = rank(for: a.description)
                let ib = rank(for: b.description)
                if ia != ib { return ia < ib }
                return a.description < b.description
            }
    }

    /// Shutter items only, ORDERED, excluding _NoConnection_
    private var shutterItemsOrdered: [(description: String, value: String)] {
        loaderMain.items
            .map {
                (description: $0.description.trimmingCharacters(in: .whitespacesAndNewlines),
                 value: $0.value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            .filter { isShutterKey($0.description) }
            .filter { !isNoConnection($0.value) }   // NEW: drop those beamlines entirely
            .sorted { a, b in
                let ia = shutterPosition(for: a.description) ?? Int.max
                let ib = shutterPosition(for: b.description) ?? Int.max
                if ia != ib { return ia < ib }
                return a.description < b.description
            }
    }

    /// Compute open/closed/unknown directly from shutter PV values.
    /// OFF = OPEN, ON = CLOSED, anything else (incl _NoConnection_) = UNKNOWN.
    private var shutterCounts: (open: Int, closed: Int, unknown: Int) {
        var open = 0
        var closed = 0
        var unknown = 0

        for item in shutterItemsOrdered {
            let v = item.value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            switch v {
            case "OFF": open += 1
            case "ON":  closed += 1
            default:    unknown += 1
            }
        }
        return (open, closed, unknown)
    }

    /// Legend texts derived from the shutter PVs (not NOpenShutters).
    private var shutterLegendTexts: (open: String, closed: String, unknown: String?) {
        let c = shutterCounts
        return ("(\(c.open)) open", "(\(c.closed)) closed", c.unknown > 0 ? "(\(c.unknown)) unknown" : nil)
    }

    // MARK: - PSS beam-ready map (from loaderPss.items)

    private var beamReadyMap: [String: String] {
        Dictionary(uniqueKeysWithValues:
            loaderPss.items.map {
                ($0.description.trimmingCharacters(in: .whitespacesAndNewlines),
                 $0.value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    /// Helper for the UI: beam-ready dot color for a shutter PV
    private func beamReadyDotColor(forShutterKey shutterKey: String,
                                   shutterValue: String) -> Color {
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

        guard let n = Int(numberString) else { return .black }

        let shutterState = shutterValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // If shutter is OPEN, dot is always magenta
        if shutterState == "OFF" {
            return Color(red: 0.9, green: 0.0, blue: 0.9)
        }

        // If shutter state is unknown (_NoConnection_), dot black
        if shutterState != "ON" {
            return .black
        }

        // Shutter CLOSED -> dot depends on PSS Station A status
        let padded = String(format: "%02d", n)
        let baseCandidates = [
            "\(prefix)\(padded)",
            "\(prefix)\(n)"
        ]

        let stationASuffixes = [
            "StaASearchedPl", // Gen 1
            "ASearched",      // Gen 3
            "StaASecureBm",   // Gen 3.4
            "StaASecureM"     // Gen 4
        ]

        var pssRaw: String? = nil
        for base in baseCandidates {
            for suffix in stationASuffixes {
                let key = base + suffix
                if let raw0 = beamReadyMap[key]?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .uppercased() {

                    // NEW: ignore unusable entries and keep searching
                    if raw0 == "_NOCONNECTION_" || raw0.isEmpty {
                        continue
                    }

                    pssRaw = raw0
                    break
                }
            }
            if pssRaw != nil { break }
        }
        guard let pss = pssRaw else { return .black }

        switch pss {
        case "ON":
            return .green
        case "OFF":
            return .orange
        default:
            return .black
        }
    }

    // MARK: - Shutter color

    private func shutterColor(for value: String) -> Color {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        switch v {
        case "ON":  return .green                       // CLOSED
        case "OFF": return Color(red: 0.9, green: 0.0, blue: 0.9) // OPEN
        default:    return .gray.opacity(0.5)           // UNKNOWN / _NoConnection_
        }
    }

    // MARK: - View

    var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if loaderMain.items.isEmpty {
                        Text(loaderMain.statusText)
                            .foregroundColor(.gray)
                            .padding()
                            .onAppear {
                                loaderMain.fetchStatus()
                                loaderPss.fetchStatus()
                            }
                    } else {
                        // Main non-shutter status
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

                        // Shutter grid and legend
                        if !shutterItemsOrdered.isEmpty {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                            Divider()
                                .padding(.vertical, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                
                                // Replace ONLY this legend HStack block inside your "Shutter status" header:

                                HStack(spacing: 12) {
                                    Text("Shutter status")
                                        .font(.headline)

                                    let legend = shutterLegendTexts

                                    // Keep all legend chips on ONE line
                                    HStack(spacing: 8) {
                                        // OPEN (magenta)
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(red: 0.9, green: 0.0, blue: 0.9))
                                                .frame(width: 80, height: 18)
                                            Text(legend.open)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }

                                        // CLOSED (green)
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.green)
                                                .frame(width: 90, height: 18)
                                            Text(legend.closed)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                        }

                                        // UNKNOWN (gray) if any
                                        if let unk = legend.unknown {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(Color.gray.opacity(0.7))
                                                    .frame(width: 105, height: 18)
                                                Text(unk)
                                                    .font(.caption2)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            }
                                        }
                                    }
                                    .layoutPriority(1)     // prevents wrapping before the title
                                    .fixedSize(horizontal: true, vertical: false) // keeps it on one line
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
                                                        beamReadyDotColor(
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

                            // Dot legend
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 8, height: 8)
                                    Text("Station A not searched")
                                        .font(.caption2)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
                .padding()
            }
            .refreshable {
                loaderMain.fetchStatus()
                loaderPss.fetchStatus()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
}

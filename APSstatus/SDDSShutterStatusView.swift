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
                // fallback: old behavior if parsing fails
                return key.replacingOccurrences(of: "ShutterClosed", with: "")
            }
            let padded = String(format: "%02d", n)
            return "\(padded)-\(prefix)"
        }

        // Non-shutter keys use the displayName map or the raw key
        return displayName[key] ?? key
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

    /// Shutter items only, filtered and ordered as before.
    private var shutterItemsOrdered: [(description: String, value: String)] {
        loaderMain.items
            .map {
                (description: $0.description.trimmingCharacters(in: .whitespacesAndNewlines),
                 value: $0.value)
            }
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

    /// Number of shutters reported open (from NOpenShutters).
    /// Returns nil if the key is missing or not an Int.
    private var numberOfOpenShutters: Int? {
        if let item = loaderMain.items.first(where: {
            $0.description.trimmingCharacters(in: .whitespacesAndNewlines) == "NOpenShutters"
        }) {
            return Int(item.value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return nil
    }

    /// Total number of shutters (used for legend). Adjust if 70 is not correct.
    private let totalShutters = 70

    /// Legend texts derived from NOpenShutters / totalShutters.
    private var shutterLegendTexts: (open: String, closed: String) {
        if let open = numberOfOpenShutters {
            let closed = max(0, totalShutters - open)
            return ("(\(open)) open", "(\(closed)) closed")
        } else {
            return ("open", "closed")
        }
    }

    // MARK: - PSS beam-ready map (from loaderPss.items)

    /// Equivalent of SDDSShutterStatusLoader.parsePssBeamReadyItems, but using the generic loader.
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

        guard let n = Int(numberString) else {
            return .black
        }

        // Determine if shutter is open or closed from shutterValue ("ON"/"OFF"/...)
        // Assumption: "ON"  = shutter CLOSED
        //             "OFF" = shutter OPEN
        let shutterState = shutterValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        // If the shutter is OPEN, dot is always magenta, regardless of PSS status
        if shutterState == "OFF" {
            // Same color you use for open shutters
            return Color(red: 0.9, green: 0.0, blue: 0.9)
        }

        // Shutter is CLOSED → dot color depends on Station A status.
        // Try both zero-padded and non-padded variants
        let padded = String(format: "%02d", n)
        let baseCandidates = [
            "\(prefix)\(padded)",
            "\(prefix)\(n)"
        ]

        // For each base (e.g. "BM01"), try all known Station A suffix forms,
        // covering Gen 1, Gen 3, Gen 3.4, and Gen 4 PSS.
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
                if let raw = beamReadyMap[key]?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
                    pssRaw = raw
                    break
                }
            }
            if pssRaw != nil { break }
        }

        // No PSS entry for Station A → black dot (missing search status)
        guard let pss = pssRaw else {
            return .black
        }

        // Station A status:
        // ON  -> searched / secure  -> green
        // OFF -> not searched       -> orange
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
        case "ON":  return .green
        case "OFF": return Color(red: 0.9, green: 0.0, blue: 0.9)
        default:    return .gray.opacity(0.5)
        }
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    // Show status while mainStatus is loading
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

                        // Shutter grid and dot legend
                        if !shutterItemsOrdered.isEmpty {
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

                            Divider()
                                .padding(.vertical, 6)

                            VStack(alignment: .leading, spacing: 4) {
                                // Title + shutter state legend
                                HStack(spacing: 12) {
                                    Text("Shutter status")
                                        .font(.headline)

                                    let legend = shutterLegendTexts

                                    // Legend for shutter rectangles with counts
                                    HStack(spacing: 8) {
                                        // OPEN (magenta) with count
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(red: 0.9, green: 0.0, blue: 0.9))
                                                .frame(width: 80, height: 18)
                                            Text(legend.open)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                        }

                                        // CLOSED (green) with count
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.green)
                                                .frame(width: 90, height: 18)
                                            Text(legend.closed)
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
}

import SwiftUI

struct SDDSStationSearchedStatusView: View {
    // Injected URL / title
    private let urlString: String
    private let title: String

    @StateObject private var loader: SDDSAllParamsLoader
    @State private var isCompact: Bool = false   // Toggle between compact / full

    init(
        urlString: String,
        title: String
    ) {
        self.urlString = urlString
        self.title = title
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
    }

    enum StationStatus {
        case searched    // ON
        case notSearched // OFF
        case unknown
    }

    struct StationEntry: Identifiable {
        let id = UUID()
        let letter: Character
        let status: StationStatus
    }

    // Stations for one beamline (ID or BM)
    struct BeamlineStations {
        let id: String            // e.g. "ID08", "BM11"
        let stations: [StationEntry]
    }

    // One row per sector: sector number + optional ID/BM stations (compact view)
    struct SectorRow: Identifiable {
        let id = UUID()
        let sector: Int
        let idStations: BeamlineStations?
        let bmStations: BeamlineStations?
    }

    // All known Station A/B/C... suffix patterns across generations
    private let stationSuffixPatterns: [String] = [
        // Gen 1
        "StaASearchedPl", "StaBSearchedPl", "StaCSearchedPl",
        "StaDSearchedPl", "StaESearchedPl", "StaFSearchedPl",
        "StaGSearchedPl", "StaHSearchedPl",
        // Gen 3
        "ASearched", "BSearched", "CSearched", "DSearched",
        "ESearched", "FSearched", "GSearched", "HSearched",
        // Gen 3.4
        "StaASecureBm", "StaBSecureBm", "StaCSecureBm",
        "StaDSecureBm", "StaESecureBm", "StaGSecureBm",
        "StaHSecureBm",
        // Gen 4
        "StaASecureM", "StaBSecureM", "StaCSecureM",
        "StaDSecureM", "StaESecureM", "StaFSecureM",
        "StaGSecureM", "StaHSecureM"
    ]

    private func color(for status: StationStatus) -> Color {
        switch status {
        case .searched:
            return .green
        case .notSearched:
            return .orange
        case .unknown:
            return Color.gray.opacity(0.4)
        }
    }

    // Beam-ready map from loader.items (Description -> ValueString)
    private var beamReadyMap: [String: String] {
        Dictionary(uniqueKeysWithValues:
            loader.items.map {
                ($0.description.trimmingCharacters(in: .whitespacesAndNewlines),
                 $0.value.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        )
    }

    // MARK: - Compact data (same logic as before, using beamReadyMap)

    private var sectorData: (rows: [SectorRow], idSegmentWidth: CGFloat) {
        // First build beamlineId -> [stationLetter: status]
        var beamlineMap: [String: [Character: StationStatus]] = [:]

        for (key, rawValue) in beamReadyMap {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            let status: StationStatus
            switch value {
            case "ON":
                status = .searched
            case "OFF":
                status = .notSearched
            default:
                status = .unknown
            }

            guard key.count >= 4 else { continue }

            let prefix = String(key.prefix(2))
            guard prefix == "BM" || prefix == "ID" else { continue }

            let afterPrefix = key.dropFirst(2)

            var numberPart = ""
            var idx = afterPrefix.startIndex
            while idx < afterPrefix.endIndex, afterPrefix[idx].isNumber {
                numberPart.append(afterPrefix[idx])
                idx = afterPrefix.index(after: idx)
            }

            guard !numberPart.isEmpty, let _ = Int(numberPart) else { continue }

            let remainder = afterPrefix[idx...]

            let stationLetter: Character?
            if remainder.hasPrefix("Sta"),
               let letterIndex = remainder.index(remainder.startIndex,
                                                 offsetBy: 3,
                                                 limitedBy: remainder.endIndex),
               letterIndex < remainder.endIndex {
                let candidate = remainder[letterIndex]
                stationLetter = (candidate.isLetter && candidate.isUppercase) ? candidate : nil
            } else if let first = remainder.first,
                      first.isLetter, first.isUppercase {
                stationLetter = first
            } else {
                stationLetter = nil
            }

            guard let letter = stationLetter else { continue }

            let padded = numberPart.count == 1 ? "0\(numberPart)" : numberPart
            let beamlineId = "\(prefix)\(padded)"

            var stationMap = beamlineMap[beamlineId] ?? [:]
            if let existing = stationMap[letter] {
                switch (existing, status) {
                case (.searched, _):
                    break
                case (.notSearched, .searched):
                    stationMap[letter] = .searched
                case (.notSearched, .notSearched), (.notSearched, .unknown):
                    break
                case (.unknown, .searched), (.unknown, .notSearched):
                    stationMap[letter] = status
                case (.unknown, .unknown):
                    break
                }
            } else {
                stationMap[letter] = status
            }
            beamlineMap[beamlineId] = stationMap
        }

        let beamlineIds = Array(beamlineMap.keys)

        var sectors = Set<Int>()
        for id in beamlineIds {
            guard id.count >= 4 else { continue }
            let numPart = id.dropFirst(2)
            if let n = Int(numPart) {
                sectors.insert(n)
            }
        }

        let sortedSectors = sectors.sorted()

        var rows: [SectorRow] = []
        var maxIdStationCount = 0

        for n in sortedSectors {
            let padded = String(format: "%02d", n)
            let idId = "ID\(padded)"
            let bmId = "BM\(padded)"

            var idStations: BeamlineStations? = nil
            var bmStations: BeamlineStations? = nil

            if let stationMap = beamlineMap[idId] {
                let letters = stationMap.keys.sorted()
                let entries = letters.map { letter in
                    StationEntry(letter: letter, status: stationMap[letter] ?? .unknown)
                }
                idStations = BeamlineStations(id: idId, stations: entries)
                maxIdStationCount = max(maxIdStationCount, entries.count)
            }

            if let stationMap = beamlineMap[bmId] {
                let letters = stationMap.keys.sorted()
                let entries = letters.map { letter in
                    StationEntry(letter: letter, status: stationMap[letter] ?? .unknown)
                }
                bmStations = BeamlineStations(id: bmId, stations: entries)
            }

            if idStations != nil || bmStations != nil {
                rows.append(SectorRow(sector: n, idStations: idStations, bmStations: bmStations))
            }
        }

        let labelWidth: CGFloat = 20
        let boxWidth: CGFloat = 22
        let spacing: CGFloat = 3

        let idSegmentWidth: CGFloat
        if maxIdStationCount > 0 {
            let boxesWidth = CGFloat(maxIdStationCount) * boxWidth
            let gapsWidth = CGFloat(maxIdStationCount - 1) * spacing
            idSegmentWidth = labelWidth + boxesWidth + gapsWidth
        } else {
            idSegmentWidth = 80
        }

        return (rows, idSegmentWidth)
    }

    // MARK: - Non-compact data (beamline-based layout)

    private var beamlineStationsFull: [BeamlineStations] {
        var result: [String: [Character: StationStatus]] = [:]

        for (key, rawValue) in beamReadyMap {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            let status: StationStatus
            switch value {
            case "ON":
                status = .searched
            case "OFF":
                status = .notSearched
            default:
                status = .unknown
            }

            guard key.count >= 4 else { continue }

            let prefix = String(key.prefix(2))
            guard prefix == "BM" || prefix == "ID" else { continue }

            let afterPrefix = key.dropFirst(2)

            var numberPart = ""
            var idx = afterPrefix.startIndex
            while idx < afterPrefix.endIndex, afterPrefix[idx].isNumber {
                numberPart.append(afterPrefix[idx])
                idx = afterPrefix.index(after: idx)
            }

            guard !numberPart.isEmpty, let n = Int(numberPart) else { continue }

            let remainder = afterPrefix[idx...]

            let stationLetter: Character?
            if remainder.hasPrefix("Sta"),
               let letterIndex = remainder.index(remainder.startIndex,
                                                 offsetBy: 3,
                                                 limitedBy: remainder.endIndex),
               letterIndex < remainder.endIndex {
                let candidate = remainder[letterIndex]
                stationLetter = (candidate.isLetter && candidate.isUppercase) ? candidate : nil
            } else if let first = remainder.first,
                      first.isLetter, first.isUppercase {
                stationLetter = first
            } else {
                stationLetter = nil
            }

            guard let letter = stationLetter else { continue }

            let padded = String(format: "%02d", n)
            let beamlineId = "\(prefix)\(padded)"

            var stationMap = result[beamlineId] ?? [:]
            if let existing = stationMap[letter] {
                switch (existing, status) {
                case (.searched, _):
                    break
                case (.notSearched, .searched):
                    stationMap[letter] = .searched
                case (.notSearched, .notSearched), (.notSearched, .unknown):
                    break
                case (.unknown, .searched), (.unknown, .notSearched):
                    stationMap[letter] = status
                case (.unknown, .unknown):
                    break
                }
            } else {
                stationMap[letter] = status
            }
            result[beamlineId] = stationMap
        }

        let beamlineIds = Array(result.keys)

        var sectors = Set<Int>()
        for id in beamlineIds {
            guard id.count >= 4 else { continue }
            let numPart = id.dropFirst(2)
            if let n = Int(numPart) {
                sectors.insert(n)
            }
        }

        let sortedSectors = sectors.sorted()
        var orderedIds: [String] = []
        for n in sortedSectors {
            let padded = String(format: "%02d", n)

            let bmId = "BM\(padded)"
            if beamlineIds.contains(bmId) {
                orderedIds.append(bmId)
            }

            let idId = "ID\(padded)"
            if beamlineIds.contains(idId) {
                orderedIds.append(idId)
            }
        }

        return orderedIds.map { beamlineId in
            let stationMap = result[beamlineId] ?? [:]
            let stationLetters = stationMap.keys.sorted()
            let entries = stationLetters.map { letter in
                StationEntry(letter: letter, status: stationMap[letter] ?? .unknown)
            }
            return BeamlineStations(id: beamlineId, stations: entries)
        }
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                if beamReadyMap.isEmpty {
                    VStack(spacing: 4) {
                        ProgressView()
                        Text(loader.statusText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .onAppear {
                        loader.fetchStatus()
                    }
                } else {
                    if isCompact {
                        compactView
                    } else {
                        fullView
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle("Compact", isOn: $isCompact)
                        .font(.caption)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loader.fetchStatus()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    // MARK: - Compact view

    private var compactView: some View {
        let data = sectorData
        let rows = data.rows
        let idSegmentWidth = data.idSegmentWidth

        return ScrollView {
            VStack(alignment: .leading, spacing: 4) {

                // Legend (centered)
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.green)
                            .frame(width: 18, height: 12)
                        Text("searched")
                            .font(.caption2)
                    }

                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.orange)
                            .frame(width: 18, height: 12)
                        Text("not searched")
                            .font(.caption2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

                // Sector rows: "01" with ID and BM on same line
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(rows) { row in
                        HStack(alignment: .center, spacing: 8) {
                            Text(String(format: "%02d", row.sector))
                                .font(.caption)
                                .frame(width: 26, alignment: .leading)

                            if let idBl = row.idStations {
                                compactBeamlineSegment(label: "ID", beamline: idBl)
                                    .frame(width: idSegmentWidth, alignment: .leading)
                            } else {
                                Spacer()
                                    .frame(width: idSegmentWidth)
                            }

                            if let bmBl = row.bmStations {
                                compactBeamlineSegment(label: "BM", beamline: bmBl)
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
    }

    private func compactBeamlineSegment(label: String, beamline: BeamlineStations) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .frame(width: 20, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(beamline.stations) { station in
                    ZStack {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color(for: station.status))
                            .frame(width: 22, height: 18)

                        Text(String(station.letter))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
    }

    // MARK: - Full view

    private var fullView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {

                // Legend
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.green)
                            .frame(width: 24, height: 16)
                        Text("searched")
                            .font(.caption2)
                    }

                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.orange)
                            .frame(width: 24, height: 16)
                        Text("not searched")
                            .font(.caption2)
                    }
                }
                .padding(.bottom, 4)

                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(beamlineStationsFull, id: \.id) { bl in
                        HStack(alignment: .center, spacing: 8) {

                            let prefix = String(bl.id.prefix(2))      // "BM" or "ID"
                            let numPart = bl.id.dropFirst(2)          // "01", "23", ...
                            let labelText = "\(numPart)-\(prefix)"

                            Text(labelText)
                                .font(.headline)
                                .frame(width: 60, alignment: .leading)

                            HStack(spacing: 6) {
                                ForEach(bl.stations) { station in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(color(for: station.status))
                                            .frame(height: 24)

                                        Text(String(station.letter))
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    .frame(width: 28, height: 24)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .padding()
        }
    }
}

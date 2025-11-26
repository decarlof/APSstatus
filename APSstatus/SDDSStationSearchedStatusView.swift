//
//  SDDSStationSearchedStatusView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/26/25.
//

import SwiftUI

struct SDDSStationSearchedStatusView: View { @ObservedObject var loader: SDDSShutterStatusLoader
    
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
    
    struct BeamlineStations: Identifiable {
        let id: String      // e.g. "ID08", "BM11"
        let stations: [StationEntry]
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
    
    // Derive a map: beamlineId -> [stationLetter: StationStatus]
    private var beamlineStations: [BeamlineStations] {
        var result: [String: [Character: StationStatus]] = [:]

        for (key, rawValue) in loader.beamReadyMap {
            // Normalize value
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

            // Determine status from ON/OFF
            let status: StationStatus
            switch value {
            case "ON":
                status = .searched
            case "OFF":
                status = .notSearched
            default:
                status = .unknown
            }

            // Key examples:
            // Gen 1 : BM01StaASearchedPl, ID02StaBSearchedPl
            // Gen 3 : BM11ASearched, ID21BSearched
            // Gen 3.4: ID04StaGSecureBm
            // Gen 4 : BM06StaASecureM, ID15StaBSecureM

            guard key.count >= 4 else { continue }

            // Beamline prefix: "BM" or "ID"
            let prefix = String(key.prefix(2))
            guard prefix == "BM" || prefix == "ID" else { continue }

            // Remove prefix
            let afterPrefix = key.dropFirst(2)

            // Beamline number digits
            var numberPart = ""
            var idx = afterPrefix.startIndex
            while idx < afterPrefix.endIndex, afterPrefix[idx].isNumber {
                numberPart.append(afterPrefix[idx])
                idx = afterPrefix.index(after: idx)
            }

            guard !numberPart.isEmpty, let n = Int(numberPart) else { continue }

            // Remainder after the number - contains station info and suffix
            let remainder = afterPrefix[idx...]

            // Determine station letter:
            //  - If remainder starts with "Sta", station letter is the next character (Gen 1, 3.4, 4).
            //  - Otherwise, station letter is the first uppercase letter (Gen 3).
            let stationLetter: Character?
            if remainder.hasPrefix("Sta"),
               let letterIndex = remainder.index(remainder.startIndex, offsetBy: 3, limitedBy: remainder.endIndex),
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

            // Normalize beamline ID to padded form (e.g., ID01, BM08)
            let padded = String(format: "%02d", n)
            let beamlineId = "\(prefix)\(padded)"

            // Store/update status:
            // If multiple PVs exist for same (beamline, station), prefer:
            //   searched > notSearched > unknown
            var stationMap = result[beamlineId] ?? [:]
            if let existing = stationMap[letter] {
                switch (existing, status) {
                case (.searched, _):
                    // keep searched
                    break
                case (.notSearched, .searched):
                    stationMap[letter] = .searched
                case (.notSearched, .notSearched), (.notSearched, .unknown):
                    // keep notSearched
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

        // Convert to sorted array:
        // Build BM01, ID01, BM02, ID02, ... order
        let beamlineIds = Array(result.keys)

        // Collect all sector numbers we actually have
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

        let sortedKeys = orderedIds

        return sortedKeys.map { beamlineId in
            let stationMap = result[beamlineId] ?? [:]
            // Sort station letters: A, B, C, ...
            let stationLetters = stationMap.keys.sorted()
            let entries = stationLetters.map { letter in
                StationEntry(letter: letter, status: stationMap[letter] ?? .unknown)
            }
            return BeamlineStations(id: beamlineId, stations: entries)
        }
}
    
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
    
    var body: some View {
        NavigationStack {
            Group {
                if loader.beamReadyMap.isEmpty {
                    VStack {
                        ProgressView()
                        Text("Loading PSS station status…")
                            .foregroundColor(.gray)
                    }
                    .onAppear {
                        // If you want only PSS: refreshPss()
                        // If you also want main status in this screen, you can call fetchStatus()
                        loader.refreshPss()
                    }

                    
                } else {
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
                                
                                // OPTIONAL: uncomment if you want to show unknown too
                                /*
                                 HStack(spacing: 4) {
                                 RoundedRectangle(cornerRadius: 4)
                                 .fill(Color.gray.opacity(0.4))
                                 .frame(width: 24, height: 16)
                                 Text("unknown")
                                 .font(.caption2)
                                 }
                                 */
                            }
                            .padding(.bottom, 4)
                            
                            // Beamline rows
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(beamlineStations) { bl in
                                    HStack(alignment: .center, spacing: 8) {

                                        // Beamline label as "01-BM", "01-ID", etc.
                                        let prefix = String(bl.id.prefix(2))      // "BM" or "ID"
                                        let numPart = bl.id.dropFirst(2)          // "01", "23", ...
                                        let labelText = "\(numPart)-\(prefix)"

                                        Text(labelText)
                                            .font(.headline)
                                            .frame(width: 60, alignment: .leading)

                                        // Horizontal row of station boxes
                                        ScrollView(.horizontal, showsIndicators: false) {
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
                                    }
                                    .padding(.vertical, 2)

                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("PSS Station Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loader.refreshPss()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

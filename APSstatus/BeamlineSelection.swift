//
//  BeamlineSelection.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 12/6/25.
//

import Foundation

struct BeamlineID: Hashable, Codable, Identifiable {
    // Example: "01-BM", "01-ID", "21-ID"
    let sector: Int
    let lineType: String  // "BM" or "ID"

    var id: String { "\(formattedSector)-\(lineType)" }

    var formattedSector: String {
        String(format: "%02d", sector)
    }

    var displayName: String {
        "\(formattedSector)-\(lineType)"
    }
}

// Storage key for UserDefaults / AppStorage
enum BeamlineSelectionKeys {
    static let selectedBeamlines = "SelectedBeamlines"
}

// Helper extension on SDDSAllParamsLoader:
//
// It assumes loader.items contains the PSS description/value pairs like:
// "BM01StaASearchedPl", "ID21BSearched", etc.
extension SDDSAllParamsLoader {

    /// Extract unique beamlines (sector + BM/ID) from Description keys.
    /// Keys look like: "BM01StaASearchedPl", "ID21BSearched", etc.
    var availableBeamlines: [BeamlineID] {
        var set = Set<BeamlineID>()

        for item in items {
            let key = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard key.count >= 4 else { continue }

            // First two chars: BM or ID
            let prefix = String(key.prefix(2)) // "BM" or "ID"
            guard prefix == "BM" || prefix == "ID" else { continue }

            // Next two chars: sector number
            let start = key.index(key.startIndex, offsetBy: 2)
            let end = key.index(start, offsetBy: 2, limitedBy: key.endIndex) ?? key.endIndex
            let sectorStr = String(key[start..<end])
            guard let sector = Int(sectorStr) else { continue }

            let beamline = BeamlineID(sector: sector, lineType: prefix)
            set.insert(beamline)
        }

        // Sort by sector, then BM/ID
        return set.sorted {
            if $0.sector == $1.sector {
                return $0.lineType < $1.lineType
            }
            return $0.sector < $1.sector
        }
    }
}

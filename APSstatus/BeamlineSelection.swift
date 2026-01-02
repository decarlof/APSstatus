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

// Curated list for Beamline Selection UI (fixed; does not require SDDS/PssData)
extension BeamlineID {

    /// Beamlines present in PssData.sdds.gz as of 2026-01-02.
    /// This list is generated as (sectors 1...40 × {ID,BM}) minus excluded entries.
    static let curated: [BeamlineID] = {
        let all = (1...40).flatMap { sector in
            [
                BeamlineID(sector: sector, lineType: "ID"),
                BeamlineID(sector: sector, lineType: "BM")
            ]
        }

        // Excluded BM sectors (missing from PssData.sdds.gz):
        // 03, 04, 15, 18, 21, 22, 24, 25, 26, 27, 28, 29, 30, 31, 32, 34, 36, 37, 38, 39, 40
        //
        // Excluded ID sectors (missing from PssData.sdds.gz):
        // 36, 37, 38, 39, 40
        let excluded: Set<BeamlineID> = [
            BeamlineID(sector: 3,  lineType: "BM"),
            BeamlineID(sector: 4,  lineType: "BM"),
            BeamlineID(sector: 15, lineType: "BM"),
            BeamlineID(sector: 18, lineType: "BM"),
            BeamlineID(sector: 21, lineType: "BM"),
            BeamlineID(sector: 22, lineType: "BM"),
            BeamlineID(sector: 24, lineType: "BM"),
            BeamlineID(sector: 25, lineType: "BM"),
            BeamlineID(sector: 26, lineType: "BM"),
            BeamlineID(sector: 27, lineType: "BM"),
            BeamlineID(sector: 28, lineType: "BM"),
            BeamlineID(sector: 29, lineType: "BM"),
            BeamlineID(sector: 30, lineType: "BM"),
            BeamlineID(sector: 31, lineType: "BM"),
            BeamlineID(sector: 32, lineType: "BM"),
            BeamlineID(sector: 34, lineType: "BM"),
            BeamlineID(sector: 36, lineType: "BM"),
            BeamlineID(sector: 37, lineType: "BM"),
            BeamlineID(sector: 38, lineType: "BM"),
            BeamlineID(sector: 39, lineType: "BM"),
            BeamlineID(sector: 40, lineType: "BM"),

            BeamlineID(sector: 36, lineType: "ID"),
            BeamlineID(sector: 37, lineType: "ID"),
            BeamlineID(sector: 38, lineType: "ID"),
            BeamlineID(sector: 39, lineType: "ID"),
            BeamlineID(sector: 40, lineType: "ID")
        ]

        return all
            .filter { !excluded.contains($0) }
            .sorted {
                if $0.sector == $1.sector { return $0.lineType < $1.lineType }
                return $0.sector < $1.sector
            }
    }()
}

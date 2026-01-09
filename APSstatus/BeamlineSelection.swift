//
//  BeamlineSelection.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 12/6/25.
//

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
    static let curated: [BeamlineID] = [
        BeamlineID(sector: 2,  lineType: "BM"),
        BeamlineID(sector: 7,  lineType: "BM"),
        BeamlineID(sector: 12, lineType: "BM"),
        BeamlineID(sector: 32, lineType: "ID")
    ]
}

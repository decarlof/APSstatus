//
//  AcceleratorSelection.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 1/17/26.
//

import Foundation

struct AcceleratorPageID: Hashable, Codable, Identifiable {
    let id: String
    let displayName: String
}

// Storage key for UserDefaults / AppStorage
enum AcceleratorSelectionKeys {
    static let selectedAcceleratorPages = "SelectedAcceleratorPages"
}

// Curated list for Accelerator Selection UI (fixed)
extension AcceleratorPageID {
    // Stable order = page order in SDDSAllView
    static let curated: [AcceleratorPageID] = [
        AcceleratorPageID(id: "aps_lnds_status",  displayName: "LNDS"),
        AcceleratorPageID(id: "sr_vacuum_status", displayName: "Vacuum"),
        AcceleratorPageID(id: "sr_klystron",      displayName: "Klystron"),
        AcceleratorPageID(id: "sr_rf_summary",    displayName: "RF"),
        AcceleratorPageID(id: "sr_ps_summary",    displayName: "PS"),
        AcceleratorPageID(id: "sr_ps_detail",     displayName: "PS Detail")
    ]
}

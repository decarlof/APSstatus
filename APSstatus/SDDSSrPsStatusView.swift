//
//  SDDSSrPsStatusView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/28/25.
//

import SwiftUI

struct SDDSSrPsStatusView: View {
    @StateObject private var loader: SDDSAllParamsLoader
    
    init(urlString: String, title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }
    
    
    private let title: String

    // MARK: - Model / Helpers

    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }

    private var valueMap: [String: String] {
        Dictionary(uniqueKeysWithValues: loader.items.map { ($0.description, $0.value) })
    }

    private func raw(_ key: String) -> String? {
        valueMap[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isOnState(_ value: String) -> Bool {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return v == "on" || v == "power on"
    }

    private func statusColor(for value: String?) -> Color {
        guard let v = value else { return .gray }
        return isOnState(v) ? .green : .red
    }

    private func sectorLabel(_ sector: Int) -> String {
        String(format: "%02d", sector)
    }

    private func digitForSector(_ sector: Int) -> String {
        let d = sector % 10
        return d == 0 ? "0" : String(d)
    }

    // Row labels for each table
    private let patternLabels: [String] = [
        "A:Q1", "A:Q2", "A:Q3", "A:Q4", "A:Q5",
        "B:Q5", "B:Q4", "B:Q3", "B:Q2", "B:Q1"
    ]

    private struct FamilyPattern {
        let label: String      // table title
        let base: String       // "Q", "S", "H", "V"
        /// elementSelector(rowIndex, isA) -> element (e.g. "1", "2", "3") or nil if no PV
        let elementSelector: (Int, Bool) -> String?
    }

    // Families with explicit mapping functions
    private var families: [FamilyPattern] {
        [
            // Quadrupole: Q1..Q5 A; B:Q5..B:Q1 – fully populated
            FamilyPattern(
                label: "Quadrupole Power Supplies",
                base: "Q",
                elementSelector: { rowIndex, isA in
                    let local = rowIndex % 5
                    if isA {
                        // A branch: Q1..Q5
                        return ["1", "2", "3", "4", "5"][local]
                    } else {
                        // B branch: Q5..Q1
                        return ["5", "4", "3", "2", "1"][local]
                    }
                }
            ),

            // Sextupole: only S1..S3 exist.
            // rows 0,1,2 => A:S1,S2,S3
            // rows 3,4   => no A sextupole -> nil (gray)
            // rows 5,6,7 => B:S3,S2,S1
            // rows 8,9   => no B sextupole -> nil (gray)
            FamilyPattern(
                label: "Sextupole Power Supplies",
                base: "S",
                elementSelector: { rowIndex, isA in
                    if isA {
                        switch rowIndex {
                        case 0: return "1"
                        case 1: return "2"
                        case 2: return "3"
                        default: return nil
                        }
                    } else {
                        switch rowIndex {
                        case 5: return "3"
                        case 6: return "2"
                        case 7: return "1"
                        default: return nil
                        }
                    }
                }
            ),

            // Horizontal correctors: only H1 and H7 in the data.
            // A-rows: H1,H7,H1,H7,H1; B-rows: same pattern shifted.
            FamilyPattern(
                label: "Horizontal Corr. Power Supplies",
                base: "H",
                elementSelector: { rowIndex, isA in
                    let slots = ["1", "7", "1", "7", "1"]
                    if isA {
                        return slots[rowIndex]
                    } else {
                        return slots[rowIndex - 5]
                    }
                }
            ),

            // Vertical correctors: V1, V7, V8.
            // A-rows: V1,V7,V8,V1,V7; B-rows: V8,V7,V1,V8,V7
            FamilyPattern(
                label: "Vertical Corr. Power Supplies",
                base: "V",
                elementSelector: { rowIndex, isA in
                    if isA {
                        let slots = ["1", "7", "8", "1", "7"]
                        return slots[rowIndex]
                    } else {
                        let slotsB = ["8", "7", "1", "8", "7"]
                        return slotsB[rowIndex - 5]
                    }
                }
            )
        ]
    }

    /// Build the PV name for a family/table row and sector.
    private func familyPVName(_ family: FamilyPattern, sector: Int, rowIndex: Int) -> String? {
        guard rowIndex >= 0 && rowIndex < 10 else { return nil }
        let isA = rowIndex < 5
        guard let elementID = family.elementSelector(rowIndex, isA) else { return nil }
        let branch = isA ? "A" : "B"
        return "S\(sectorLabel(sector))\(branch):\(family.base)\(elementID)"
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if loader.items.isEmpty {
                        Text(loader.statusText)
                            .foregroundColor(.gray)
                            .padding()
                            .onAppear { loader.fetchStatus() }
                    } else {
                        if let update = updateTime {
                            Text("Updated: \(update)")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                        }

                        ForEach(Array(families.enumerated()), id: \.offset) { _, family in
                            familyTableTransposed(family)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 16)
            }
            .refreshable { loader.fetchStatus() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Family Table (10 rows × 40 columns)

    private func familyTableTransposed(_ family: FamilyPattern) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(family.label)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .center)

            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 4) {
                    // Header row: sector digits 1..40
                    HStack(spacing: 1) {
                        Text("")
                            .frame(width: 50, alignment: .leading)

                        ForEach(1...40, id: \.self) { sector in
                            Text(digitForSector(sector))
                                .font(.caption2)
                                .frame(width: 10, alignment: .center)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 10 rows
                    ForEach(0..<patternLabels.count, id: \.self) { rowIndex in
                        HStack(spacing: 1) {
                            Text(patternLabels[rowIndex])
                                .font(.caption2)
                                .frame(width: 50, alignment: .leading)

                            ForEach(1...40, id: \.self) { sector in
                                let pvName = familyPVName(family, sector: sector, rowIndex: rowIndex)
                                let value = pvName.flatMap { raw($0) }
                                let color = statusColor(for: value)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(color)
                                        .frame(width: 10, height: 12)

                                    Text(digitForSector(sector))
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                    }

                    // Legend
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                            Text("ON / Power On")
                                .font(.caption2)
                        }

                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                            Text("OFF / other")
                                .font(.caption2)
                        }

                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray)
                                .frame(width: 12, height: 12)
                            Text("Unknown / N/A")
                                .font(.caption2)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(8)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.secondarySystemBackground))
            )
        }
    }
}

//
//  SrPsSummaryView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 12/06/25.
//

import SwiftUI

struct SrPsSummaryView: View {
    @StateObject private var loader: SDDSAllParamsLoader
    private let title: String

    init(urlString: String, title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }

    // MARK: - Model

    enum Family: String, CaseIterable, Identifiable {
        case fastHCor   = "Fast H Cor"
        case fastVCor   = "Fast V Cor"
        case hCor       = "H Cor"
        case vCor       = "V Cor"
        case skewQuad   = "Skew Quad"
        case quad       = "Quad"
        case sext       = "Sext"
        case dipole     = "Dipole"
        case dipoleTrim = "Dipole Trim"
        case m1         = "M1"
        case m2         = "M2"
        case fanout     = "Fanout"
        case raw        = "Raw"

        var id: String { rawValue }

        /// Prefix used in SDDS Description
        var keyPrefix: String {
            switch self {
            case .fastHCor:   return "FastHCorStatusStatus"
            case .fastVCor:   return "FastVCorStatusStatus"
            case .hCor:       return "HCorStatusStatus"
            case .vCor:       return "VCorStatusStatus"
            case .skewQuad:   return "SkewQuadStatusStatus"
            case .quad:       return "QuadStatusStatus"
            case .sext:       return "SextStatusStatus"
            case .dipole:     return "DipoleStatusStatus"
            case .dipoleTrim: return "DipoleTrimStatusStatus"
            case .m1:         return "M1StatusStatus"
            case .m2:         return "M2StatusStatus"
            case .fanout:     return "FanoutStatusStatus"
            case .raw:        return "RawStatusStatus"
            }
        }
    }

    struct FamilyStatus {
        var status0: String?
        var status1: String?
        var status2: String?
    }

    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }

    private var familyMap: [Family: FamilyStatus] {
        var map: [Family: FamilyStatus] = [:]

        for item in loader.items {
            let key = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value

            if key == "UpdateTime" {
                continue
            }

            guard let family = Family.allCases.first(where: { key.hasPrefix($0.keyPrefix) }) else {
                continue
            }

            var status = map[family] ?? FamilyStatus()

            if key.hasSuffix("0") {
                status.status0 = value
            } else if key.hasSuffix("1") {
                status.status1 = value
            } else if key.hasSuffix("2") {
                status.status2 = value
            }

            map[family] = status
        }

        return map
    }

    // MARK: - View

    var body: some View {
             ScrollView {
                VStack(alignment: .leading, spacing: 12) {
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
                                .padding(.horizontal)
                        }

                        summaryTable
                            .padding(.horizontal)
                    }
                }
                .padding(.top)
            }
            .refreshable { loader.fetchStatus() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
}

    // MARK: - Compact Table (RF style)

    private var summaryTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row similar in style to RF table
            HStack {
                Text("Family")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Status 0")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
                Text("Status 1")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
                Text("Status 2")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.bottom, 2)

            ForEach(Family.allCases) { family in
                let status = familyMap[family] ?? FamilyStatus()
                summaryRow(family: family, status: status)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func summaryRow(family: Family, status: FamilyStatus) -> some View {
        HStack {
            Text(family.rawValue)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(status.status0?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-")
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)

            Text(status.status1?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-")
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)

            Text(status.status2?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "-")
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

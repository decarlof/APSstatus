//
//  SDDSVacuumStatusView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/29/25.
//

import SwiftUI

struct SDDSVacuumStatusView: View {
    @StateObject private var loader: SDDSAllParamsLoader

    init(urlString: String, title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }

    private let title: String

    // MARK: - Model

    struct VacuumSector: Identifiable {
        let id = UUID()
        let sector: Int

        struct Valve: Identifiable {
            let id = UUID()
            let label: String   // "V1", "V2", "V3"
            let isOpen: Bool?
        }

        struct Gauge: Identifiable {
            let id = UUID()
            let label: String   // "Ring", "ID", "Branch"
            let alarm: String?  // "NO_ALARM", or other, or nil if missing
        }

        var valves: [Valve]
        var gauges: [Gauge]
    }

    // MARK: - Layout constants

    private let sectorColWidth: CGFloat = 32
    private let valveCellWidth: CGFloat = 24    // header + cell
    private let valveCellHeight: CGFloat = 14
    private let gaugeCellWidth: CGFloat = 50
    private let gaugeCellHeight: CGFloat = 14

    // MARK: - Helpers

    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }

    private var valueMap: [String: String] {
        Dictionary(uniqueKeysWithValues: loader.items.map { ($0.description, $0.value) })
    }

    private func value(for key: String) -> String? {
        valueMap[key]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValveOpen(_ value: String?) -> Bool? {
        guard let v = value?.lowercased() else { return nil }
        if v.contains("open") { return true }
        if v.contains("closed") { return false }
        return nil
    }

    private func gaugeStateColor(_ alarm: String?) -> Color {
        guard let alarm = alarm else { return .gray.opacity(0.4) }
        return alarm == "NO_ALARM" ? .green : .red
    }

    private func valveColor(_ isOpen: Bool?) -> Color {
        guard let state = isOpen else { return .gray.opacity(0.4) }
        return state ? .green : .red
    }

    /// Parse sectors 1–40 into VacuumSector rows.
    private var sectors: [VacuumSector] {
        var result: [VacuumSector] = []

        for n in 1...40 {
            let sectorString = String(format: "%02d", n)
            let base = "S\(sectorString)"

            // --- Valves: V1, V2, V3 ---

            var valves: [VacuumSector.Valve] = []

            // V1
            var v1Value: String?
            if let v = value(for: "\(base)A:GV1") {
                v1Value = v
            }
            valves.append(
                VacuumSector.Valve(label: "V1", isOpen: isValveOpen(v1Value))
            )

            // V2
            var v2Value: String?
            if let v = value(for: "\(base)B:GV1") {
                v2Value = v
            } else if n == 38, let v = value(for: "S38-BLS:GV1") {
                // Special case for S38 BLS line: treat GV1 as V2
                v2Value = v
            }
            valves.append(
                VacuumSector.Valve(label: "V2", isOpen: isValveOpen(v2Value))
            )

            // V3 (C branch or BLS second valve)
            var v3Value: String?
            if let v = value(for: "\(base)C:GV1") {
                v3Value = v
            } else if n == 38, let v = value(for: "S38-BLS:GV2") {
                v3Value = v
            }
            valves.append(
                VacuumSector.Valve(label: "V3", isOpen: isValveOpen(v3Value))
            )

            // --- Gauges: Ring CCG1, ID CCG1, Branch gauges ---

            var gauges: [VacuumSector.Gauge] = []

            // Ring gauge CCG1: "S01:CCG1"
            let ringCCG = value(for: "\(base):CCG1")
            gauges.append(
                VacuumSector.Gauge(label: "Ring", alarm: ringCCG)
            )

            // ID gauge CCG1: "S01ID:CCG1"
            let idCCG = value(for: "\(base)ID:CCG1")
            gauges.append(
                VacuumSector.Gauge(label: "ID", alarm: idCCG)
            )

            // Branch gauges: SnnC:CCG1, SnnC:CCG2 (if present)
            let branchC1 = value(for: "\(base)C:CCG1")
            if branchC1 != nil {
                gauges.append(VacuumSector.Gauge(label: "Branch", alarm: branchC1))
            }

            let branchC2 = value(for: "\(base)C:CCG2")
            if branchC2 != nil {
                gauges.append(VacuumSector.Gauge(label: "Branch", alarm: branchC2))
            }

            // Only include sectors that have at least one valve or gauge defined
            let hasAnyValve = valves.contains { $0.isOpen != nil }
            let hasAnyGauge = gauges.contains { $0.alarm != nil }

            if hasAnyValve || hasAnyGauge {
                result.append(
                    VacuumSector(
                        sector: n,
                        valves: valves,
                        gauges: gauges
                    )
                )
            }
        }

        return result
    }

    // MARK: - View

    var body: some View {
        NavigationStack {
            Group {
                if loader.items.isEmpty {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text(loader.statusText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .onAppear {
                        loader.fetchStatus()
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if let update = updateTime {
                                Text("Updated: \(update)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.horizontal)
                            }

                            // Legend
                            HStack(spacing: 12) {
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.green)
                                        .frame(width: 18, height: 12)
                                    Text("OK / Open / NO_ALARM")
                                        .font(.caption2)
                                }

                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.red)
                                        .frame(width: 18, height: 12)
                                    Text("Closed / Alarm")
                                        .font(.caption2)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.bottom, 4)

                            // Header row: align labels with boxes
                            HStack(alignment: .bottom, spacing: 8) {
                                Text("Sec")
                                    .font(.caption2)
                                    .frame(width: sectorColWidth, alignment: .leading)

                                // Valve header cells
                                HStack(spacing: 4) {
                                    Text("V1")
                                        .font(.caption2)
                                        .frame(width: valveCellWidth, alignment: .center)
                                    Text("V2")
                                        .font(.caption2)
                                        .frame(width: valveCellWidth, alignment: .center)
                                    Text("V3")
                                        .font(.caption2)
                                        .frame(width: valveCellWidth, alignment: .center)
                                }
                                .frame(width: valveCellWidth * 3 + 2 * 4, alignment: .leading)

                                // Gauge header cells
                                HStack(spacing: 4) {
                                    Text("Ring")
                                        .font(.caption2)
                                        .frame(width: gaugeCellWidth, alignment: .center)
                                    Text("ID")
                                        .font(.caption2)
                                        .frame(width: gaugeCellWidth, alignment: .center)
                                    Text("Branch")
                                        .font(.caption2)
                                        .frame(width: gaugeCellWidth, alignment: .center)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 8)
                            .padding(.bottom, 2)

                            Divider()

                            // Sector rows (grid-like look)
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(sectors) { sec in
                                    HStack(alignment: .center, spacing: 8) {
                                        // Sector label: "01", "02", ...
                                        Text(String(format: "%02d", sec.sector))
                                            .font(.caption)
                                            .frame(width: sectorColWidth, alignment: .leading)

                                        // Valves: V1, V2, V3 (aligned under header)
                                        HStack(spacing: 4) {
                                            ForEach(sec.valves) { valve in
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(valveColor(valve.isOpen))
                                                        .frame(width: valveCellWidth,
                                                               height: valveCellHeight)

                                                    Text(valve.label)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .frame(width: valveCellWidth * 3 + 2 * 4,
                                               alignment: .leading)

                                        // Gauges: Ring, ID, Branch
                                        HStack(spacing: 4) {
                                            ForEach(sec.gauges) { g in
                                                ZStack {
                                                    RoundedRectangle(cornerRadius: 3)
                                                        .fill(gaugeStateColor(g.alarm))
                                                        .frame(width: gaugeCellWidth,
                                                               height: gaugeCellHeight)

                                                    Text(g.label)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundColor(.white)
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.horizontal, 8)
                                }
                            }
                            .padding(.bottom, 8)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
}

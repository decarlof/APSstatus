//
//  SDDSLNDSStatusView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/28/25.
//

import SwiftUI

struct SDDSLNDSStatusView: View {
    @StateObject private var loader: SDDSAllParamsLoader

    init(urlString: String,
         title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }

    private let title: String

    // MARK: - Model / Helpers

    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }

    /// Quick lookup dictionary: "ATS1" -> "-171.638", etc.
    private var valueMap: [String: String] {
        Dictionary(uniqueKeysWithValues: loader.items.map { ($0.description, $0.value) })
    }

    /// Access a value by key, returning "-" if missing.
    private func v(_ key: String?) -> String {
        guard let key = key, !key.isEmpty else { return "-" }
        if let raw = valueMap[key] {
            return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "-"
    }

    /// Basic 0/1 mapping for dewar / KF valves
    private func valveState(_ key: String?) -> String {
        let raw = v(key)
        if let num = Int(raw) {
            // 0 = closed, 1 = open (adjust to your convention)
            return num == 0 ? "Closed" : "Open"
        }
        return raw
    }

    /// Specialized mapping for the Inter‑Dewar valves: "Shut / Not shut"
    private func interValveState(_ key: String?) -> String {
        let raw = v(key)
        if let num = Int(raw) {
            // 0 = Shut, 1 = Not shut (change text if reversed)
            return num == 0 ? "Shut" : "Not shut"
        }
        return raw
    }

    /// Read sector valve raw value "S1Vlv"..."S35Vlv"
    private func sectorValveValue(sector: Int) -> String {
        let key = "S\(sector)Vlv"
        return v(key)  // uses v(_:) from above; returns "-" if missing
    }

    /// Map numeric valve state to color
    private func sectorValveColor(for value: String) -> Color {
        if let n = Int(value) {
            switch n {
            case 1:
                return .green   // open
            case 0:
                return .red     // closed
            default:
                return .gray    // unexpected but numeric
            }
        }
        return .gray            // non-numeric
    }

    /// Human‑readable text from numeric sector valve value (not used in UI now, but available)
    private func sectorValveText(for value: String) -> String {
        if let n = Int(value) {
            return n == 1 ? "Open" : "Closed"
        }
        return "Unknown"
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

                        // Main LNDS table
                        lndsTable
                            .padding(.horizontal)

                        // Inter‑Dewar valve status table
                        interDewarTable
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // Sector Valve Status
                        sectorValveStatusView
                            .padding(.horizontal)
                            .padding(.top, 8)
                    }
                }
                .padding(.top)
            }
            .refreshable {
                loader.fetchStatus()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - LNDS Main Table

    private var lndsTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack {
                Text("") // empty top-left corner
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("A")
                    .font(.caption)
                    .frame(width: 60, alignment: .center)
                Text("B")
                    .font(.caption)
                    .frame(width: 60, alignment: .center)
                Text("C")
                    .font(.caption)
                    .frame(width: 60, alignment: .center)
                Text("D")
                    .font(.caption)
                    .frame(width: 60, alignment: .center)
            }
            .padding(.bottom, 2)

            // --- Temperature rows TS1–TS6 (C) ---
            lndsRow(label: "TS1 (C)",
                    a: v("ATS1"),
                    b: v("BTS1"),
                    c: v("CTS1"),
                    d: v("DTS1"))

            lndsRow(label: "TS2 (C)",
                    a: v("ATS2"),
                    b: v("BTS2"),
                    c: v("CTS2"),
                    d: v("DTS2"))

            lndsRow(label: "TS3 (C)",
                    a: v("ATS3"),
                    b: v("BTS3"),
                    c: v("CTS3"),
                    d: v("DTS3"))

            // Only DTS4 exists
            lndsRow(label: "TS4 (C)",
                    a: "-",
                    b: "-",
                    c: "-",
                    d: v("DTS4"))

            lndsRow(label: "TS5 (C)",
                    a: v("ATS5"),
                    b: v("BTS5"),
                    c: v("CTS5"),
                    d: v("DTS5"))

            lndsRow(label: "TS6 (C)",
                    a: v("ATS6"),
                    b: v("BTS6"),
                    c: v("CTS6"),
                    d: v("DTS6"))

            Divider().padding(.vertical, 4)

            // --- Dewar / Rate / KF Valves ---
            lndsRow(label: "Dewar Valve",
                    a: valveState("ADwrVlv"),
                    b: valveState("BDwrVlv"),
                    c: valveState("CDwrVlv"),
                    d: valveState("DDwrVlv"))

            lndsRow(label: "DewarPress (psi)",
                    a: v("ADwrPrsr"),
                    b: v("BDwrPrsr"),
                    c: v("CDwrPrsr"),
                    d: v("DDwrPrsr"))

            lndsRow(label: "DevarLevel",
                    a: v("ADwrLvl"),
                    b: v("BDwrLvl"),
                    c: v("CDwrLvl"),
                    d: v("DDwrLvl"))

            lndsRow(label: "Rate",
                    a: v("ARate"),
                    b: v("BRate"),
                    c: v("CRate"),
                    d: v("DRate"))

            lndsRow(label: "KF1 Valve",
                    a: valveState("AKF1Vlv"),
                    b: valveState("BKF1Vlv"),
                    c: valveState("CKF1Vlv"),
                    d: valveState("DKF1Vlv"))

            lndsRow(label: "KF2 Valve",
                    a: valveState("AKF2Vlv"),
                    b: valveState("BKF2Vlv"),
                    c: valveState("CKF2Vlv"),
                    d: valveState("DKF2Vlv"))
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - Inter‑Dewar Valve Table

    private var interDewarTable: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Inter‑Dewar Valve Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 2)

            HStack {
                Text("")  // left header cell
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("A-B")
                    .font(.caption)
                    .frame(width: 70, alignment: .center)
                Text("B-C")
                    .font(.caption)
                    .frame(width: 70, alignment: .center)
                Text("C-D")
                    .font(.caption)
                    .frame(width: 70, alignment: .center)
            }
            .padding(.bottom, 2)

            HStack {
                Text("Valve")
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(interValveState("ABVlv"))
                    .font(.caption2)
                    .frame(width: 70, alignment: .center)

                Text(interValveState("BCVlv"))
                    .font(.caption2)
                    .frame(width: 70, alignment: .center)

                Text(interValveState("CDVlv"))
                    .font(.caption2)
                    .frame(width: 70, alignment: .center)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - Sector Valve Status

    private var sectorValveStatusView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sector Valve Status")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)

            // 7 x 5 grid: 35 sectors total
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7),
                alignment: .center,
                spacing: 8
            ) {
                ForEach(1...35, id: \.self) { sector in
                    let raw = sectorValveValue(sector: sector)
                    let color = sectorValveColor(for: raw)

                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(color)
                            .frame(height: 32)

                        Text(String(format: "%02d", sector))
                            .font(.caption)
                            .foregroundColor(.white)
                            .bold()
                    }
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.green)
                        .frame(width: 18, height: 18)
                    Text("Open")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.red)
                        .frame(width: 18, height: 18)
                    Text("Closed")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray)
                        .frame(width: 18, height: 18)
                    Text("Unknown / N/A")
                        .font(.caption)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    // MARK: - Generic row builder

    private func lndsRow(label: String,
                         a: String,
                         b: String,
                         c: String,
                         d: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(a)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)

            Text(b)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)

            Text(c)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)

            Text(d)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)
        }
    }
}

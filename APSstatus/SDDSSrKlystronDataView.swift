//
//  SDDSSrKlystronDataView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 12/06/25.
//

import SwiftUI

struct SDDSSrKlystronDataView: View {
    @StateObject private var loader: SDDSAllParamsLoader

    init(urlString: String, title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }

    private let title: String

    // MARK: - Model

    enum RFStation: Int, CaseIterable, Identifiable {
        case rf1 = 1
        case rf2 = 2
        case rf3 = 3
        case rf4 = 4

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .rf1: return "RF1"
            case .rf2: return "RF2"
            case .rf3: return "RF3"
            case .rf4: return "RF4"
            }
        }

        /// Suffix used in SDDS description names
        var suffix: String {
            switch self {
            case .rf1: return ""       // no suffix
            case .rf2: return "RF2"
            case .rf3: return "RF3"
            case .rf4: return "RF4"
            }
        }
    }

    enum StatusQuality {
        case good
        case bad
        case unknown
    }

    struct KlyRow: Identifiable {
        let id = UUID()
        let label: String  // row label
        // per-station raw values and quality
        var values: [RFStation: String?]
        var qualities: [RFStation: StatusQuality]
    }

    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }

    private var valueMap: [String: String] {
        Dictionary(uniqueKeysWithValues: loader.items.map { ($0.description, $0.value) })
    }

    private func value(for desc: String) -> String? {
        valueMap[desc]?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Status interpretation

    private func classifyStatus(_ value: String?) -> StatusQuality {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !v.isEmpty else {
            return .unknown
        }

        let upper = v.uppercased()

        // Good / OK-ish
        if upper == "ON" || upper == "READY" || upper == "OK" || upper == "NO_ALARM" {
            return .good
        }
        // lowercase "ok"
        if v == "ok" {
            return .good
        }

        // Bad / fault-ish
        if upper == "OFF" || upper == "TRIP" || upper == "FAULT" || upper.contains("NOT READY") {
            return .bad
        }

        return .unknown
    }

    private func classifyNumeric(_ raw: String?) -> (StatusQuality, Double?) {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let n = Double(trimmed) else {
            return (.unknown, nil)
        }
        if n > 0 {
            return (.good, n)
        } else if n < 0 {
            return (.bad, n)
        } else {
            return (.unknown, n)
        }
    }

    private func color(for quality: StatusQuality) -> Color {
        switch quality {
        case .good:    return .green
        case .bad:     return .red
        case .unknown: return .gray.opacity(0.4)
        }
    }

    // MARK: - Build table rows

    private var tableRows: [KlyRow] {
        // Common row definitions (same for all RF stations)
        let statusDefs: [(String, String)] = [
            ("UVC power",            "UVCpowerOnStat"),
            ("Cathode supply",       "cathodeSupplyOnOff"),
            ("HV ready",             "highVoltageReady"),
            ("Mod anode",            "modAnodeOnOff"),
            ("Mod anode ready",      "modAnodeReady"),
            ("Heater",               "heaterOnOffStatus"),
            ("Heater supply ready",  "heaterSupplyReady"),
            ("Mag1 supply",          "mag1SupplyOnOff"),
            ("Mag1 ready",           "mag1SupplyReady"),
            ("Mag2 supply",          "mag2SupplyOnOff"),
            ("Mag2 ready",           "mag2SupplyReady"),
            ("Ion pump",             "ionPumpOnOff"),
            ("Ion pump ready",       "ionPumpReady"),
            ("VESDA smoke",          "VesdaSmokeDetector"),
            ("RF ACIS HVPS",         "RFACISHVPS"),
            ("RF drive ACIS",        "RFDriveACISStatus"),
            ("PwrMon status",        "PwrMon"),
            ("Collector power",      "CollectorPwr"),
            ("PSS intr tally OK",    "PssIntrTallyOK"),
            ("RF intr tally OK",     "RfIntrTallyOK"),
            ("PSS relay NO",         "PssIntrRelayNO"),
            ("RF relay NO",          "RfIntrRelayNO"),
            ("RF drive status",      "RFDriveStatus")
        ]

        let numericDefs: [(String, String)] = [
            ("RF power (kW)",        "Ch1KWatt"),
            ("HVPS unit fault",      "HVPSUnitFault"),
            ("Kly driver status",    "KlyDriverStatus"),
            ("Anode current",        "anodeCurrent"),
            ("Anode voltage",        "anodeVoltage"),
            ("Beam current",         "beamCurrent"),
            ("Beam voltage",         "beamVoltage"),
            ("Cathode V ref",        "cathodeVReference"),
            ("Mod anode V ref",      "modAnodeVReference")
        ]

        var rows: [KlyRow] = []

        // status-type rows
        for (label, baseKey) in statusDefs {
            var values: [RFStation: String?] = [:]
            var qualities: [RFStation: StatusQuality] = [:]

            for station in RFStation.allCases {
                let key = baseKey + station.suffix
                let raw = value(for: key)
                let q = classifyStatus(raw)
                values[station] = raw
                qualities[station] = q
            }

            // keep row if any station has data
            let anyValue = values.values.contains { $0 != nil }
            if anyValue {
                rows.append(KlyRow(label: label, values: values, qualities: qualities))
            }
        }

        // numeric rows
        for (label, baseKey) in numericDefs {
            var values: [RFStation: String?] = [:]
            var qualities: [RFStation: StatusQuality] = [:]

            for station in RFStation.allCases {
                let key = baseKey + station.suffix
                let raw = value(for: key)
                let (q, _) = classifyNumeric(raw)
                values[station] = raw
                qualities[station] = q
            }

            let anyValue = values.values.contains { $0 != nil }
            if anyValue {
                rows.append(KlyRow(label: label, values: values, qualities: qualities))
            }
        }

        // Sort rows alphabetically by the label column
        return rows.sorted { $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending }
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
                    ScrollView(.vertical) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let update = updateTime {
                                Text("Updated: \(update)")
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.horizontal)
                            }

                            legendView
                                .padding(.horizontal)

                            tableView
                                .padding(.horizontal)
                        }
                        .padding(.top, 8)
                    }
                    .refreshable {
                        loader.fetchStatus()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Legend

    private var legendView: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.green)
                    .frame(width: 18, height: 12)
                Text("ON / READY / OK / > 0")
                    .font(.caption2)
            }

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.red)
                    .frame(width: 18, height: 12)
                Text("OFF / FAULT / TRIP / < 0")
                    .font(.caption2)
            }

            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 18, height: 12)
                Text("Unknown / 0 / missing")
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Table (one big table with RF1–RF4 columns)

    private var tableView: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header row
            HStack(spacing: 4) {
                Text("Signal")
                    .font(.caption2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(RFStation.allCases) { station in
                    Text(station.label)
                        .font(.caption2)
                        .frame(width: 72, alignment: .center)
                }
            }
            .padding(.bottom, 2)

            Divider()

            // Data rows
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(tableRows) { row in
                    HStack(spacing: 4) {
                        Text(row.label)
                            .font(.caption2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        ForEach(RFStation.allCases) { station in
                            let raw = row.values[station] ?? nil
                            let quality = row.qualities[station] ?? .unknown
                            klyCell(raw: raw, quality: quality)
                        }
                    }
                }
            }
            .padding(.top, 2)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }

    private func klyCell(raw: String?, quality: StatusQuality) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(color(for: quality))
                .frame(width: 72, height: 16)

            let text: String = {
                guard let r = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !r.isEmpty else { return "-" }
                return r
            }()

            Text(text)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

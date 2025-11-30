//
//  SDDSRfCompactView.swift
//  APSstatus
//
//  Created by Francesco De Carlo on 11/26/25.
//
import SwiftUI

struct SDDSRfCompactView: View { @StateObject private var loader: SDDSAllParamsLoader
    
    init(urlString: String, title: String) {
        _loader = StateObject(wrappedValue: SDDSAllParamsLoader(urlString: urlString))
        self.title = title
    }
    
    private let title: String
    
    // MARK: - Model
    
    struct RFStat {
        var min: String?
        var ave: String?
        var max: String?
    }
    
    struct SectorData {
        let sector: Int
        var voltage   = RFStat()
        var fwdPwr    = RFStat()
        var refPwr    = RFStat()
        var cavPres   = RFStat()
        var cplTemp   = RFStat()
    }
    
    private var updateTime: String? {
        loader.items.first(where: { $0.description == "UpdateTime" })?.value
    }
    
    // Only these sectors are shown; change as needed
    private let sectorsOfInterest: [Int] = [36, 37, 40]
    
    private var sectorMap: [Int: SectorData] {
        var map: [Int: SectorData] = [:]
        
        for item in loader.items {
            let key = item.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value
            
            if key == "UpdateTime" {
                continue
            }
            if key.hasPrefix("SrTotalVolt") {
                // Global SR total volt handled separately if needed
                continue
            }
            
            // Keys like: S36CavFwdPwrMin, S37CplTempAve, S40TotalVoltMax, etc.
            guard key.hasPrefix("S") else { continue }
            
            var digits = ""
            var idx = key.index(after: key.startIndex) // skip 'S'
            while idx < key.endIndex, key[idx].isNumber {
                digits.append(key[idx])
                idx = key.index(after: idx)
            }
            guard let sector = Int(digits) else { continue }
            guard sectorsOfInterest.contains(sector) else { continue }
            
            var sectorData = map[sector] ?? SectorData(sector: sector)
            
            let suffix = String(key[idx...]) // e.g. "CavFwdPwrMin"
            let (metric, moment) = parseMetricAndMoment(from: suffix)
            
            guard let m = metric, let mom = moment else { continue }
            
            func assign(_ stat: inout RFStat) {
                switch mom {
                case .min:
                    stat.min = value
                case .ave:
                    stat.ave = value
                case .max:
                    stat.max = value
                }
            }
            
            switch m {
            case .voltage:
                assign(&sectorData.voltage)
            case .fwdPwr:
                assign(&sectorData.fwdPwr)
            case .refPwr:
                assign(&sectorData.refPwr)
            case .cavPres:
                assign(&sectorData.cavPres)
            case .cplTemp:
                assign(&sectorData.cplTemp)
            }
            
            map[sector] = sectorData
        }
        
        return map
    }
    
    private enum Metric {
        case voltage      // TotalVolt
        case fwdPwr       // CavFwdPwr
        case refPwr       // CavRefPwr
        case cavPres      // CavPres
        case cplTemp      // CplTemp
    }
    
    private enum Moment {
        case min
        case ave
        case max
    }
    
    private func parseMetricAndMoment(from suffix: String) -> (Metric?, Moment?) {
        // suffix examples:
        //   "CavFwdPwrMin", "CavFwdPwrAve", "CavFwdPwrMax"
        //   "CavPresMin",   "CavPresAve",   "CavPresMax"
        //   "CavRefPwrMin", "CavRefPwrAve","CavRefPwrMax"
        //   "CplTempMin",   "CplTempAve",   "CplTempMax"
        //   "TotalVoltMin", "TotalVoltAve","TotalVoltMax"
        
        var base = suffix
        var moment: Moment?
        
        if base.hasSuffix("Min") {
            moment = .min
            base.removeLast(3)
        } else if base.hasSuffix("Ave") {
            moment = .ave
            base.removeLast(3)
        } else if base.hasSuffix("Max") {
            moment = .max
            base.removeLast(3)
        } else {
            // For this compact view we only care about Min/Ave/Max,
            // and ignore "current" values (no suffix).
            return (nil, nil)
        }
        
        let metric: Metric?
        switch base {
        case "TotalVolt":
            metric = .voltage
        case "CavFwdPwr":
            metric = .fwdPwr
        case "CavRefPwr":
            metric = .refPwr
        case "CavPres":
            metric = .cavPres
        case "CplTemp":
            metric = .cplTemp
        default:
            metric = nil
        }
        
        return (metric, metric == nil ? nil : moment)
    }
    
    // MARK: - View
    
    var body: some View {
        NavigationStack {
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
                                .padding(.horizontal)
                        }
                        
                        // Show sectors in numeric order: 36, 37, 40
                        let sectors = sectorsOfInterest.filter { sectorMap[$0] != nil }
                        
                        ForEach(sectors, id: \.self) { s in
                            if let data = sectorMap[s] {
                                sectorTable(for: data)
                                    .padding(.horizontal)
                            }
                        }
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
    }
    
    // MARK: - Sector Table
    
    @ViewBuilder
    private func sectorTable(for data: SectorData) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header
            HStack {
                Text("Sector \(data.sector)")
                    .font(.headline)
                Spacer()
                Text("Min")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
                Text("Ave")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
                Text("Max")
                    .font(.caption)
                    .frame(width: 60, alignment: .trailing)
            }
            .padding(.bottom, 2)
            
            // Rows
            rfRow(label: "Voltage (MV)", stat: data.voltage)
            rfRow(label: "Fwd Pwr (kW)", stat: data.fwdPwr)
            rfRow(label: "Ref Pwr (kW)", stat: data.refPwr)
            rfRow(label: "Cav Pres (nt)", stat: data.cavPres)
            // Temperature converted from °F to °C and label updated
            rfRow(label: "Cpl Temp (°C)", stat: data.cplTemp, isTempCelsius: true)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
    
    // MARK: - Rows and Conversion
    
    private func rfRow(label: String,
                       stat: RFStat,
                       isTempCelsius: Bool = false) -> some View {
        // Optionally convert F → C for temperature
        let minVal = isTempCelsius && stat.min != nil ? fahrenheitToCelsius(stat.min!) : (stat.min ?? "-")
        let aveVal = isTempCelsius && stat.ave != nil ? fahrenheitToCelsius(stat.ave!) : (stat.ave ?? "-")
        let maxVal = isTempCelsius && stat.max != nil ? fahrenheitToCelsius(stat.max!) : (stat.max ?? "-")
        
        return HStack {
            Text(label)
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(minVal)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)
            
            Text(aveVal)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)
            
            Text(maxVal)
                .font(.caption2)
                .frame(width: 60, alignment: .trailing)
        }
    }
    
    private func fahrenheitToCelsius(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let f = Double(trimmed) else {
            return trimmed   // if it’s not a number, return as-is
        }
        let c = (f - 32.0) * 5.0 / 9.0
        return String(format: "%.1f", c)
    }
}

import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSLoader()

    // Map SDDS Description -> Friendly label
    private let displayName: [String: String] = [
        "ScheduledMode":  "Scheduled Mode",
        "ActualMode":     "Actual Mode",
        "TopupState":     "Top-up",
        "InjOperation":   "Injector",
        "ShutterStatus":  "Shutters",
        "UpdateTime":     "Updated",
        "OPSMessage1":    "MCR Crew",
        "OPSMessage2":    "Floor Coord",
        "OPSMessage3":    "Fill Pattern",
        "OPSMessage4":    "Last Dump/Trip",
        "OPSMessage5":    "Problem Info",
        "Current":        "Current",
        "Lifetime":       "Lifetime"
    ]

    // Desired order by ORIGINAL SDDS keys (Description)
    private let orderByKey = [
        "Current",
        "Lifetime",
        "TopupState",
        "InjOperation",
        "ScheduledMode",
        "ActualMode",
        "ShutterStatus",
        "OPSMessage3", // Fill Pattern
        "OPSMessage1", // MCR Crew
        "OPSMessage2", // Floor Coord
        "OPSMessage4", // Last Dump/Trip
        "OPSMessage5", // Problem Info
        "UpdateTime"
    ]

    private var keyRank: [String: Int] {
        Dictionary(uniqueKeysWithValues: orderByKey.enumerated().map { ($1, $0) })
    }

    private var sortedItems: [(description: String, value: String)] {
        loader.extractedData.sorted { a, b in
            let ia = keyRank[a.description] ?? Int.max
            let ib = keyRank[b.description] ?? Int.max
            if ia != ib { return ia < ib }
            return a.description < b.description
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if loader.extractedData.isEmpty {
                    Text(loader.statusText)
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear { loader.fetchStatus() }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(sortedItems, id: \.description) { item in
                                HStack {
                                    Text((displayName[item.description] ?? item.description) + ":")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    
                                    // ✅ Color "Current" value based on threshold
                                    if item.description == "Current",
                                       let currentValue = Double(item.value) {
                                        Text(item.value)
                                            .foregroundColor(currentValue > 100 ? .green : .red)
                                            .fontWeight(.bold)
                                    } else {
                                        Text(item.value)
                                    }
                                }
                                Divider()
                                
                                // Separator after "Fill Pattern"
                                if item.description == "OPSMessage3" {
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.4))
                                        .frame(height: 2)
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("APS Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") { loader.fetchStatus() }
                }
            }
        }
    }
}

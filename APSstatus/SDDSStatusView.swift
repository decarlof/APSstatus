import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSLoader()

    var body: some View {
        VStack {
            Text(loader.statusText)
                .padding()

            List {
                ForEach(loader.columns, id: \.self) { col in
                    VStack(alignment: .leading) {
                        Text(col).bold()
                        if let values = loader.dataDict[col] {
                            // Show first 10 values for brevity
                            Text(values.prefix(10).map { "\($0)" }.joined(separator: ", "))
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .onAppear { loader.fetchStatus() }
        .navigationTitle("APS SDDS Status")
    }
}

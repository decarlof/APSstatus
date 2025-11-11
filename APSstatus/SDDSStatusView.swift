import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSLoader()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                if loader.extractedData.isEmpty {
                    Text(loader.statusText)
                        .foregroundColor(.gray)
                        .padding()
                        .onAppear {
                            loader.fetchStatus()
                        }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(loader.extractedData, id: \.description) { item in
                                HStack {
                                    Text(item.description + ":")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Text(item.value)
                                }
                                Divider()
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
                    Button("Refresh") {
                        loader.fetchStatus()
                    }
                }
            }
        }
    }
}

#Preview {
    SDDSStatusView()
}

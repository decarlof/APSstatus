import SwiftUI

struct SDDSStatusView: View {
    @StateObject private var loader = SDDSLoader()
    
    var body: some View {
        NavigationStack {
            VStack {
                Text(loader.statusText)
                    .padding()
                    .multilineTextAlignment(.center)
                
                Button("Reload Data") {
                    loader.fetchAndDecompressSDDS()
                }
                .padding()
            }
            .navigationTitle("Machine Status")
        }
        .onAppear {
            loader.fetchAndDecompressSDDS()
        }
    }
}

#Preview {
    SDDSStatusView()
}

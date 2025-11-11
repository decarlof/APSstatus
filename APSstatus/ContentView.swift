import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            StatusImagesView()
                .tabItem {
                    Label("Status", systemImage: "photo.on.rectangle")
                }

            SDDSStatusView()
                .tabItem {
                    Label("Machine", systemImage: "waveform.path.ecg")
                }
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                
                // Main label
                Text("APSStatus (converted)")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                // Home images from APS server
                HomeImagesView()
                    .frame(height: 120)
                
                // Navigation buttons
                HStack(spacing: 50) {
                    NavigationLink("About", destination: AboutView())
                    NavigationLink("Settings", destination: SettingsView())
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            .padding()
            .navigationTitle("APSStatus")
        }
    }
}

#Preview {
    ContentView()
}

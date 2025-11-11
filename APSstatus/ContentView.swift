import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Text("APSStatus (converted)")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
                
                HStack {
                    NavigationLink("About", destination: AboutView())
                    Spacer()
                    NavigationLink("Settings", destination: SettingsView())
                }
                .padding(.horizontal)
            }
            .navigationTitle("APSStatus")
        }
    }
}

#Preview {
    ContentView()
}

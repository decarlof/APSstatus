import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("APSStatus")
                .font(.largeTitle)
                .bold()
            
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            Text("Version \(version)")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Text("Originally developed by Michael Borland.\nThis is the SwiftUI converted version.")
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("About")
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}

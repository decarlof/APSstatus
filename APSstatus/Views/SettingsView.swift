import SwiftUI

struct SettingsView: View {
    // Use @AppStorage to persist preferences automatically
    @AppStorage("enableNotifications") private var enableNotifications = true
    @AppStorage("darkMode") private var darkMode = false

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Button("Open App Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            Section(header: Text("Preferences")) {
                Toggle("Enable Notifications", isOn: $enableNotifications)
                Toggle("Dark Mode", isOn: $darkMode)
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

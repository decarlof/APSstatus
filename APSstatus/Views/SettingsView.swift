import SwiftUI

struct SettingsView: View {
    // Existing preferences
    @AppStorage("enableNotifications") private var enableNotifications = true

    var body: some View {
        Form {
            Section(header: Text("Beamlines")) {
                // Help text inside the Beamlines section
                Text("Select the beamlines you are interested in. If you would like a custom beamline status page, please provide the EPICS PVs for your beamline so they can be included in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink("Beamline Selection") {
                    BeamlineSelectionView()
                }
            }

            Section(header: Text("Preferences")) {
                Toggle("Enable Notifications", isOn: $enableNotifications)
            }
        }
        .navigationTitle("Settings")
    }
}

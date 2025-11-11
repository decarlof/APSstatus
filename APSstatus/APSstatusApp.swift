import SwiftUI

@main
struct APSStatusApp: App {
    // Persist Dark Mode preference
    @AppStorage("darkMode") private var darkMode = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Apply Dark or Light mode based on the preference
                .preferredColorScheme(darkMode ? .dark : .light)
        }
    }
}

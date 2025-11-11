APSStatus iOS conversion (partial)

What I generated:
- AppDelegate.swift
- SceneDelegate.swift
- MainViewController.swift
- SDDSReader.swift (stub)

Where to go from here (recommended next steps):
1. Create a new Xcode project (App template, Swift, UIKit or SwiftUI).
2. Copy these Swift files into the Xcode project.
3. Implement SDDSReader.read(from:) to parse SDDS files. The original project used SDDS.jar (Java). You can:
   - Port the SDDS parsing logic to Swift (preferred for native),
   - Or create a small backend service that converts SDDS to JSON and fetch on the app,
   - Or use a bridging approach (e.g., write a C/C++ parser and call from Swift).
4. Port Android widgets to iOS WidgetKit (requires SwiftUI) as separate targets (Widget Extension).
5. Port services/background tasks to iOS background fetch/URLSession/background processing or use App Groups + BackgroundTasks.
6. Review permissions and entitlements (e.g., network, file access).
7. Translate UI components (Android fragments -> UIViewController or SwiftUI views).
8. Test on device/simulator; iterate.

I can continue converting more Java files (widgets, services, util classes) into Swift. Tell me to proceed and I'll convert the next batch automatically.

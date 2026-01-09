import SwiftUI

struct SDDSAllView: View {
    // Web status image URLs (single source of truth)
    private let webStatusImageURLs = [
        "https://www3.aps.anl.gov/asd/operations/gifplots/HDSRcomfort.png",
        "https://www3.aps.anl.gov/aod/blops/plots/WeekHistory.png"
    ]

    private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"

    //    https://ops.aps.anl.gov/sddsStatus/SrVacStatus.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/mainStatus.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/SCU0.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/SrRfSummary.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/SCU1.sdds.gz             // <— not connected
    //    https://ops.aps.anl.gov/sddsStatus/SrPsStatus.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/HSCU7.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/SRKlystronData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/IEXData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/PssData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/FeepsData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/LNDSData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/MpsData.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/SrPsSummary.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/mainSummary.sdds.gz
    //    https://ops.aps.anl.gov/sddsStatus/mainSummaryBig1.sdds.gz

    // SDDS parameter pages (filename, title)
    // Note: I removed LNDSData.sdds.gz from here, since it now has its own custom view.
    private let sddsPages: [(file: String, title: String)] = [
        // ("FeepsData.sdds.gz",          "FEEPS Data"),          // <- PVs are not connected
        // ("HSCU7.sdds.gz",              "HSCU 7"),              // <- PVs are not connected
        // ("IEXData.sdds.gz",            "IEX Data"),            // <- PVs are not connected
        // ("LNDSData.sdds.gz",           "LNDS Data"),        // <- App page implemented
        // ("MpsData.sdds.gz",            "MPS Data"),            // <- PVs are not connected
        // ("mainStatus.sdds.gz",         "Main Status"),      // <- App page implemented
        // ("mainSummary.sdds.gz",        "Main Summary"),        // <- no additional info compared to mainStatus.sdds.gz
        // ("mainSummaryBig1.sdds.gz",    "Main Summary Big 1"),  // <- some PVs are not connected
        // ("PssData.sdds.gz",            "PSS Data"),         // <- App page implemented
        // ("SCU0.sdds.gz",               "SCU 0"),               // <- PVs are not connected
        // ("SCU1.sdds.gz",               "SCU 1"),               // <- PVs are not connected
        // ("SrPsStatus.sdds.gz",         "SR PS Status"),     // <- App page implemented
        // ("SrPsSummary.sdds.gz",        "SR PS Summary"),    // <- App page implemented
        // ("SrRfSummary.sdds.gz",        "SR RF Summary"),    // <- App page implemented
        // ("SrVacStatus.sdds.gz",        "SR Vac Status"),    // <- App page implemented
        // ("SRKlystronData.sdds.gz",     "SR Klystron Data")  // <- App page implemented
    ]

    enum ActiveSheet: Identifiable {
        case about
        case settings
        var id: Int { self == .about ? 0 : 1 }
    }

    @State private var activeSheet: ActiveSheet? = nil

    // NEW: selection to support highlighting current dot + tap-to-jump
    @State private var selection: Int = 0

    @AppStorage(BeamlineSelectionKeys.selectedBeamlines)
    private var selectedBeamlinesData: Data = Data()

    // Tracks whether Settings/About sheet is currently presented from page 0
    @State private var isPresentingSheet: Bool = false

    // Beamline IDs currently applied to the pager (freeze while sheet is open)
    @State private var appliedBeamlineIDs: [String] = []

    // Latest decoded selection (updates while sheet is open, but does not change pager)
    @State private var pendingBeamlineIDs: [String] = []

    private func decodeSelectedBeamlines() -> [String] {
        guard !selectedBeamlinesData.isEmpty,
              let decoded = try? JSONDecoder().decode([String].self, from: selectedBeamlinesData)
        else { return [] }
        return decoded
    }

    private var beamlinePagesInOrder: [String] {
        // Keep a stable, predictable order at the end of the page list
        let order = ["02-BM", "07-BM", "12-BM", "32-ID"]
        let selected = Set(appliedBeamlineIDs)
        return order.filter { selected.contains($0) }
    }

    // NEW: total page count (9 fixed pages + remaining generic pages)
    private var totalPages: Int { 9 + sddsPages.count + beamlinePagesInOrder.count }

    // NEW: show/hide dots after inactivity
    @State private var showDots: Bool = true
    @State private var hideDotsTaskID: UUID = UUID()

    // NEW: call this any time the user interacts to show dots and restart the 1s hide timer
    private func showDotsThenAutoHide() {
        showDots = true

        // Freeze dot auto-hide while Settings/About is presented
        if isPresentingSheet { return }

        // Do not run the dot system on the home page anymore
        if selection == 0 { return }

        let taskID = UUID()
        hideDotsTaskID = taskID
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard hideDotsTaskID == taskID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showDots = false
            }
        }
    }

    private struct SwipeRightHint: View {
        var body: some View {
            HStack(spacing: 8) {
                Text("Swipe right")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(.bottom, 8)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TabView(selection: $selection) {

                    // Page 0: Web status
                    WebStatusView(imageURLs: webStatusImageURLs, activeSheet: $activeSheet)
                        .tag(0)

                    // Page 1: Shutter status / APS main status
                    SDDSShutterStatusView(
                        mainStatusURL: baseURL + "mainStatus.sdds.gz",
                        pssDataURL:    baseURL + "PssData.sdds.gz",
                        title: "APS Status"
                    )
                    .tag(1)

                    // Page 2: PSS station searched/secure status
                    SDDSStationSearchedStatusView(
                        urlString: baseURL + "PssData.sdds.gz",
                        title: "PSS Station Status"
                    )
                    .tag(2)

                    // Page 3: APS LNDS Status
                    SDDSLNDSStatusView(
                        urlString: baseURL + "LNDSData.sdds.gz",
                        title: "APS LNDS Status"
                    )
                    .tag(3)

                    // Page 4: SR Vacuum Status
                    SDDSVacuumStatusView(
                        urlString: baseURL + "SrVacStatus.sdds.gz",
                        title: "SR Vacuum Status"
                    )
                    .tag(4)

                    // Page 5: SR PS Status Detail
                    SDDSSrKlystronDataView(
                        urlString: baseURL + "SRKlystronData.sdds.gz",
                        title: "SR Klystron"
                    )
                    .tag(5)

                    // Page 6: SR PS Status Detail
                    SDDSSrPsStatusView(
                        urlString: baseURL + "SrPsStatus.sdds.gz",
                        title: "APS Storage Ring PS Status Detail"
                    )
                    .tag(6)

                    // Page 7: Compact SR RF summary
                    SDDSRfCompactView(
                        urlString: baseURL + "SrRfSummary.sdds.gz",
                        title: "SR RF Summary"
                    )
                    .tag(7)

                    // Page 8: SR PS Status Detail
                    SrPsSummaryView(
                        urlString: baseURL + "SrPsSummary.sdds.gz",
                        title: "SR PS Summary"
                    )
                    .tag(8)

                    // Remaining SDDS parameter pages (generic viewer)
                    ForEach(Array(sddsPages.enumerated()), id: \.element.file) { idx, entry in
                        SDDSAllParamsView(
                            urlString: baseURL + entry.file,
                            title: entry.title
                        )
                        .tag(9 + idx)
                    }

                    let beamlineBaseTag = 9 + sddsPages.count

                    ForEach(Array(beamlinePagesInOrder.enumerated()), id: \.element) { idx, blID in
                        Group {
                            if blID == "02-BM" {
                                Beamline02BMView()
                            } else if blID == "07-BM" {
                                Beamline07BMView()
                            } else if blID == "12-BM" {
                                Beamline12BMView()
                            } else if blID == "32-ID" {
                                Beamline32IDView()
                            }
                        }
                        .tag(beamlineBaseTag + idx)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // NEW: hide system dots
                // NEW: show dots on any touch; doesn't block swipes/taps in subviews
                // NOTE: Removed the touch-capturing DragGesture(minimumDistance: 0) because it breaks controls in subviews (e.g., Settings beamline selection).
                .onAppear {
                    let decoded = decodeSelectedBeamlines()
                    pendingBeamlineIDs = decoded
                    appliedBeamlineIDs = decoded
                    if selection != 0 {
                        showDotsThenAutoHide()
                    }
                }
                .onChange(of: selectedBeamlinesData) { _ in
                    pendingBeamlineIDs = decodeSelectedBeamlines()

                    // If Settings/About is open, do NOT change the pager structure.
                    guard !isPresentingSheet else { return }

                    appliedBeamlineIDs = pendingBeamlineIDs

                    if selection >= totalPages {
                        selection = max(0, totalPages - 1)
                    }
                }
                // NEW: show dots when the page changes (swipe left/right)
                .onChange(of: selection) { _ in
                    if isPresentingSheet { return }
                    showDotsThenAutoHide()
                }

                // NEW: SwiftUI-only dots (tap to jump), auto-hide after 1s inactivity
                if selection == 0 {
                    SwipeRightHint()
                } else if showDots {
                    HStack(spacing: 8) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Circle()
                                .fill(i == selection ? Color.primary : Color.secondary.opacity(0.35))
                                .frame(width: 7, height: 7)
                                .contentShape(Rectangle()) // makes tapping easier
                                .onTapGesture {
                                    // Touch shows dots and restarts timer
                                    showDotsThenAutoHide()

                                    // Instant jump (no rapid multi-swipe animation)
                                    selection = i
                                }
                                .accessibilityLabel("Page \(i + 1) of \(totalPages)")
                                .accessibilityAddTraits(i == selection ? [.isSelected] : [])
                        }
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                    .transition(.opacity)
                }
            }
            .sheet(item: $activeSheet, onDismiss: {
                activeSheet = nil
            }) { sheet in
                switch sheet {
                case .about:
                    NavigationStack {
                        AboutView()
                            .navigationTitle("About")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                            .navigationTitle("Settings")
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
            }
            .onChange(of: activeSheet) { newValue in
                isPresentingSheet = (newValue != nil)
                if newValue == nil {
                    appliedBeamlineIDs = pendingBeamlineIDs
                    if selection >= totalPages {
                        selection = max(0, totalPages - 1)
                    }
                }
            }
        }
    }
}

#Preview {
    SDDSAllView()
}

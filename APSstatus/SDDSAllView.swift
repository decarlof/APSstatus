import SwiftUI

struct SDDSAllView: View {
    private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"
    
    // Shared loader for APS status + PSS
    @StateObject private var loader = SDDSShutterStatusLoader()
    
    // SDDS parameter pages (filename, title)
    // Note: I removed LNDSData.sdds.gz from here, since it now has its own custom view.
    private let sddsPages: [(file: String, title: String)] = [
        ("SrVacStatus.sdds.gz",    "SR Vacuum"),
        ("SrRfSummary.sdds.gz",    "SR RF Summary"),
        // ("PssData.sdds.gz",        "PSS"),
        ("SrPsStatus.sdds.gz",     "SR PS Status"),
        ("SRKlystronData.sdds.gz", "SR Klystron Data"),
        // ("FeepsData.sdds.gz",      "FEEPS Data"),
        // ("LNDSData.sdds.gz",       "LNDS Data"),  // <— keep commented/removed
    ]
    
    var body: some View {
        TabView {
            // Page 0: Web status (unchanged)
            WebStatusView()
            
            // Page 1: Shutter status / APS main status
            SDDSShutterStatusView(loader: loader)
            
            // Page 2: PSS station searched/secure status
            SDDSStationSearchedStatusView(loader: loader)
            
            // Page 3: Compact SR RF summary
            SDDSRfCompactView(
                urlString: baseURL + "SrRfSummary.sdds.gz",
                title: "SR RF Summary"
            )
            
            // Page 4: APS LNDS Status
            SDDSLNDSStatusView(
                urlString: baseURL + "LNDSData.sdds.gz",
                title: "APS LNDS Status"
            )
            
            // Remaining SDDS parameter pages (generic viewer)
            ForEach(sddsPages, id: \.file) { entry in
                SDDSAllParamsView(
                    urlString: baseURL + entry.file,
                    title: entry.title
                )
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // swipe horizontally, no tab bar
    }
}

#Preview {
    SDDSAllView()
}

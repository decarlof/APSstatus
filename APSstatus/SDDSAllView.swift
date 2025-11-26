import SwiftUI

struct SDDSAllView: View { private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"
    
    // Shared loader for APS status + PSS
    @StateObject private var loader = SDDSShutterStatusLoader()
    
    // SDDS parameter pages (filename, title)
    private let sddsPages: [(file: String, title: String)] = [
        ("SrVacStatus.sdds.gz",    "SR Vacuum"),
        ("SrRfSummary.sdds.gz",    "SR RF Summary"),
        ("PssData.sdds.gz",        "PSS"),
        ("SrPsStatus.sdds.gz",     "SR PS Status"),
        ("SRKlystronData.sdds.gz", "SR Klystron Data"),
        ("PssData.sdds.gz",        "PSS Data"),
        ("FeepsData.sdds.gz",      "FEEPS Data"),
    ]
    
    var body: some View {
        TabView {
            // Page 0: Web status (unchanged)
            WebStatusView()
            
            // Page 1: Shutter status / APS main status
            SDDSShutterStatusView(loader: loader)
            
            // Page 2: PSS station searched/secure status (new)
            SDDSStationSearchedStatusView(loader: loader)
            
            // Remaining SDDS parameter pages
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

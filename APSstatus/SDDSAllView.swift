import SwiftUI

struct SDDSAllView: View { private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"
    
//    https://ops.aps.anl.gov/sddsStatus/SrVacStatus.sdds.gz
//    https://ops.aps.anl.gov/sddsStatus/mainStatus.sdds.gz
//    https://ops.aps.anl.gov/sddsStatus/SCU0.sdds.gz
//    https://ops.aps.anl.gov/sddsStatus/SrRfSummary.sdds.gz
//    https://ops.aps.anl.gov/sddsStatus/SCU1.sdds.gz
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
    
    
    
    // Shared loader for APS status + PSS
    @StateObject private var loader = SDDSShutterStatusLoader()
    
    // SDDS parameter pages (filename, title)
    private let sddsPages: [(file: String, title: String)] = [
        ("SrVacStatus.sdds.gz",    "SR Vacuum"),
        ("SrRfSummary.sdds.gz",    "SR RF Summary"),
        // ("PssData.sdds.gz",        "PSS"),
        ("SrPsStatus.sdds.gz",     "SR PS Status"),
        ("SRKlystronData.sdds.gz", "SR Klystron Data"),
        // ("FeepsData.sdds.gz",      "FEEPS Data"),
    ]
    
    var body: some View {
        TabView {
            // Page 0: Web status (unchanged)
            WebStatusView()
            
            // Page 1: Shutter status / APS main status
            SDDSShutterStatusView(loader: loader)
            
            // Page 2: PSS station searched/secure status (new)
            SDDSStationSearchedStatusView(loader: loader)
            
            // Page 3: Compact SR RF summary
            SDDSRfCompactView(
                urlString: baseURL + "SrRfSummary.sdds.gz",
                title: "SR RF Summary"
            )
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

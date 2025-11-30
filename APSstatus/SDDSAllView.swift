import SwiftUI

struct SDDSAllView: View {
    private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"
    
    // Shared loader for APS status + PSS
    // @StateObject private var loader = SDDSShutterStatusLoader()

    
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
        ("SrVacStatus.sdds.gz",    "SR Vacuum"),
        // ("SrRfSummary.sdds.gz",    "SR RF Summary"),
        // ("PssData.sdds.gz",        "PSS"),
        ("SrPsStatus.sdds.gz",     "SR PS Status"),
        ("SRKlystronData.sdds.gz", "SR Klystron Data"),
        // ("FeepsData.sdds.gz",      "FEEPS Data"),
        // ("LNDSData.sdds.gz",       "LNDS Data"),  // <— keep commented/removed
    ]
    
    var body: some View {
        TabView {
            WebStatusView()

            // Shutter status / APS main status (refactored)
            SDDSShutterStatusView()

            // PSS station searched/secure status (refactored)
            SDDSStationSearchedStatusView()

            SDDSLNDSStatusView(
                urlString: baseURL + "LNDSData.sdds.gz",
                title: "APS LNDS Status"
            )

            SDDSVacuumStatusView(
                urlString: baseURL + "SrVacStatus.sdds.gz",
                title: "SR Vacuum Status"
            )

            SDDSRfCompactView(
                urlString: baseURL + "SrRfSummary.sdds.gz",
                title: "SR RF Summary"
            )

            SDDSSrPsStatusView(
                urlString: baseURL + "SrPsStatus.sdds.gz",
                title: "APS Storage Ring PS Status Detail"
            )

            ForEach(sddsPages, id: \.file) { entry in
                SDDSAllParamsView(
                    urlString: baseURL + entry.file,
                    title: entry.title
                )
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}

#Preview {
    SDDSAllView()
}

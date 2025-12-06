import SwiftUI

struct SDDSAllView: View {
    // Web status image URLs (single source of truth)
    private let webStatusImageURLs = [
        "https://www3.aps.anl.gov/asd/operations/gifplots/HDSRcomfort.png",
        "https://www3.aps.anl.gov/aod/blops/plots/WeekHistory.png"
    ]
 
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
        ("SRKlystronData.sdds.gz",     "SR Klystron Data")
    ]
    
    var body: some View {
        TabView {
            // Page 0: Web status
            WebStatusView(imageURLs: webStatusImageURLs)
            
            // Page 1: Shutter status / APS main status
            SDDSShutterStatusView(
                mainStatusURL: baseURL + "mainStatus.sdds.gz",
                pssDataURL:    baseURL + "PssData.sdds.gz",
                title: "APS Status"
            )

            // Page 2: PSS station searched/secure status
            SDDSStationSearchedStatusView(
                urlString: baseURL + "PssData.sdds.gz",
                title: "PSS Station Status"
            )

            // Page 3: APS LNDS Status
            SDDSLNDSStatusView(
                urlString: baseURL + "LNDSData.sdds.gz",
                title: "APS LNDS Status"
            )

            // Page 4: SR Vacuum Status
            SDDSVacuumStatusView(
                urlString: baseURL + "SrVacStatus.sdds.gz",
                title: "SR Vacuum Status"
            )

            // Page 5: Compact SR RF summary
            SDDSRfCompactView(
                urlString: baseURL + "SrRfSummary.sdds.gz",
                title: "SR RF Summary"
            )

            // Page 6: SR PS Status Detail
            SDDSSrPsStatusView(
                urlString: baseURL + "SrPsStatus.sdds.gz",
                title: "APS Storage Ring PS Status Detail"
            )

            // Page 7: SR PS Status Detail
            SrPsSummaryView(
                urlString: baseURL + "SrPsSummary.sdds.gz",
                title: "SR PS Summary"
            )
            // Page 8: SR PS Status Detail
            SDDSSrKlystronDataView(
                urlString: baseURL + "SRKlystronData.sdds.gz",
                title: "SR Klystron"
            )
            // Remaining SDDS parameter pages (generic viewer)
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

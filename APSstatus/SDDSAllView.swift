import SwiftUI

struct SDDSAllView: View {
    private let baseURL = "https://ops.aps.anl.gov/sddsStatus/"

    // Existing SwiftUI pages
    private let staticPages: [AnyView] = [
        AnyView(WebStatusView()),
        AnyView(SDDSStatusView())
    ]

    // New SDDS pages (filename, title)
    private let sddsPages: [(file: String, title: String)] = [
        // Already-added examples
        ("SrVacStatus.sdds.gz",    "SR Vacuum"),
        // ("SCU0.sdds.gz",           "SCU0"),
        ("SrRfSummary.sdds.gz",    "SR RF Summary"),
        ("PssData.sdds.gz",           "PSS"),
        // ("SCU1.sdds.gz",           "SCU1"),
        ("SrPsStatus.sdds.gz",     "SR PS Status"),
        // ("HSCU7.sdds.gz",          "HSCU7"),
        ("SRKlystronData.sdds.gz", "SR Klystron Data"),
        // ("IEXData.sdds.gz",        "IEX Data"),
        ("PssData.sdds.gz",        "PSS Data"),
        ("FeepsData.sdds.gz",      "FEEPS Data"),
        // ("LNDSData.sdds.gz",       "LNDS Data"),
        // ("MpsData.sdds.gz",        "MPS Data"),
        // ("SrPsSummary.sdds.gz",    "SR PS Summary"),
        // ("mainSummary.sdds.gz",    "Main Summary"),
        // ("mainSummaryBig1.sdds.gz","Main Summary Big1")
    ]

    var body: some View {
        TabView {
            // First two pages
            ForEach(Array(staticPages.enumerated()), id: \.offset) { _, page in
                page
            }

            // SDDS parameter pages
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

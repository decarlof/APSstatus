import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            StatusImagesView()
                .tag(0)

            SDDSStatusView()
                .tag(1)

            // New pages from the same base URL
            SDDSAllParamsView(
                urlString: "https://ops.aps.anl.gov/sddsStatus/SrVacStatus.sdds.gz",
                title: "SR Vacuum"
            )
            .tag(2)

            SDDSAllParamsView(
                urlString: "https://ops.aps.anl.gov/sddsStatus/SCU0.sdds.gz",
                title: "SCU0"
            )
            .tag(3)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never)) // swipeable pages, no bottom tabs
    }
}

#Preview {
    ContentView()
}

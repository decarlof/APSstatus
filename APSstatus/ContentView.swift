import SwiftUI

struct ContentView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            StatusImagesView()
                .tag(0)

            SDDSStatusView()
                .tag(1)
        }
        // iOS 14+ syntax to make it swipeable pages and hide dots
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
    }
}

#Preview {
    ContentView()
}
